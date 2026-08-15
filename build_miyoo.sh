#!/bin/bash
# Cross-compilation script for OpenClaw (Miyoo Mini / OnionOS)
# Uses the native Miyoo toolchain + libSDL2 (see miyoo_toolchain.cmake) — do not
# regenerate that file here, it is hand-tuned (sysroot, cortex-a7 flags, rpath fix).

set -e

echo "=== Preparing OpenClaw build for Miyoo Mini ==="

# Stage the platform extension header (MMIYOO_SetTextureColorKey,
# MMIYOO_GetRenderStats) from the SDL fork into the toolchain sysroot. The SDL
# build script also does this, but it runs in its own throwaway container, so
# that copy dies with it and this build would compile against whatever stale
# copy happens to be baked into the image - silently, until a newly added
# symbol fails to resolve. Copy it here so the two always agree.
SDL_EXT_HEADER="openclaw-src/../sdl2-miyoo-src/sdl2/include/SDL_mmiyoo_ext.h"
SYSROOT_SDL2_INCLUDE="/opt/miyoomini-toolchain/usr/arm-linux-gnueabihf/sysroot/usr/include/SDL2"
if [ -f "$SDL_EXT_HEADER" ] && [ -d "$SYSROOT_SDL2_INCLUDE" ]; then
    cp -f "$SDL_EXT_HEADER" "$SYSROOT_SDL2_INCLUDE/"
    echo "Staged SDL_mmiyoo_ext.h into toolchain sysroot"
fi

# Same for the library itself: link against the libSDL2 we are actually going to
# ship (device-libs-upload/, produced by build-scripts/build_custom_sdl2.sh)
# rather than the copy frozen into the builder image, or newly exported symbols
# fail to resolve at link time even though the deployed library has them.
SDL_LIB="device-libs-upload/libSDL2-2.0.so.0.18.2"
SYSROOT_LIB="/opt/miyoomini-toolchain/usr/arm-linux-gnueabihf/sysroot/usr/lib"
if [ -f "$SDL_LIB" ] && [ -d "$SYSROOT_LIB" ]; then
    cp -f "$SDL_LIB" "$SYSROOT_LIB/libSDL2-2.0.so.0"
    echo "Staged freshly built libSDL2 into toolchain sysroot"
fi

# Bake an identifier into the binary. Crash reports carry raw addresses that
# only resolve against the exact build they came from, so a report from a user
# is worthless unless it names its build - see docs/REPORTING_CRASHES.md.
git config --global --add safe.directory /workspace/openclaw-src 2>/dev/null || true
# No --dirty: the tree is checked out on Windows with autocrlf, so git inside
# this container sees every text file as modified and every build would claim to
# be dirty. The commit hash is what actually identifies the build.
BUILD_ID=$(git -C openclaw-src describe --always --tags 2>/dev/null || true)
if [ -z "$BUILD_ID" ]; then
    BUILD_ID="nogit-$(date -u +%Y%m%d-%H%M%S)"
fi
echo "Build ID: $BUILD_ID"

mkdir -p build-miyoo
cd build-miyoo

cmake ../openclaw-src -DCMAKE_TOOLCHAIN_FILE=../miyoo_toolchain.cmake -DCMAKE_BUILD_TYPE=Release -DMIYOO_BUILD_ID="$BUILD_ID"
make -j$(nproc)

echo "=== Build complete ==="
echo "Binary openclaw created in build-miyoo/"
