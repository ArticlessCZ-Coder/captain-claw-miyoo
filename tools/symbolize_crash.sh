#!/bin/bash
# Turns the raw addresses in a user's crash report into function names and
# source lines.
#
#   tools/symbolize_crash.sh <crash-report.txt> [openclaw.unstripped]
#
# The binary must be the *exact* build the report came from - the report's
# "build:" line names it, and every release publishes the matching
# openclaw.unstripped as an asset. A mismatched binary does not fail, it just
# prints confidently wrong function names, so the build id is checked below.
#
# Runs addr2line from the cross toolchain: natively if it is on PATH, otherwise
# through the builder image (same one build_miyoo.sh uses).

set -e

REPORT="$1"
BINARY="${2:-Build_Release/openclaw.unstripped}"

if [ -z "$REPORT" ] || [ ! -f "$REPORT" ]; then
    echo "usage: $0 <crash-report.txt> [openclaw.unstripped]" >&2
    exit 1
fi
if [ ! -f "$BINARY" ]; then
    echo "error: binary not found: $BINARY" >&2
    exit 1
fi

REPORT_BUILD=$(grep -m1 '^build:' "$REPORT" | sed 's/^build:[[:space:]]*//' || true)
echo "report build: ${REPORT_BUILD:-<none stated>}"
echo "binary:       $BINARY"
if [ -n "$REPORT_BUILD" ] && ! strings "$BINARY" | grep -qF "$REPORT_BUILD"; then
    echo "WARNING: '$REPORT_BUILD' does not appear in this binary - the addresses" >&2
    echo "         below will resolve to the wrong functions. Get the matching" >&2
    echo "         openclaw.unstripped from that release." >&2
fi
echo

# pc/lr from the register line plus every backtrace frame, in report order.
ADDRESSES=$(
    {
        grep -m1 '^pc:' "$REPORT" | grep -o '0x[0-9a-f]\+'
        grep -o '^  #[0-9]\+  0x[0-9a-f]\+' "$REPORT" | grep -o '0x[0-9a-f]\+'
    } 2>/dev/null | awk '!seen[$0]++'
)

if [ -z "$ADDRESSES" ]; then
    echo "no addresses found in $REPORT" >&2
    exit 1
fi

if command -v arm-linux-gnueabihf-addr2line >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    arm-linux-gnueabihf-addr2line -f -C -i -e "$BINARY" $ADDRESSES
else
    echo "(arm-linux-gnueabihf-addr2line not on PATH, using the builder image)"
    echo
    MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd)":/workspace -w /workspace \
        openclaw-miyoo-builder:latest \
        arm-linux-gnueabihf-addr2line -f -C -i -e "$BINARY" $ADDRESSES
fi

# Addresses inside libSDL2 (typically 0xb6......) resolve against the library,
# not the game - the report's memory map section shows where it was loaded.
