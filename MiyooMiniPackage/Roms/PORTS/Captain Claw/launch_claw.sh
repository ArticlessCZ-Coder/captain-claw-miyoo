#!/bin/sh
cd "/mnt/SDCARD/Roms/PORTS/Games/Captain Claw"

# Make executable
chmod +x ./openclaw

# Export library path
export LD_LIBRARY_PATH=".:./lib:./libs:/mnt/SDCARD/.tmp_update/lib/parasyte:$LD_LIBRARY_PATH"

# Native Miyoo Mini SDL2 build only implements the "mmiyoo" video/audio backends
# (SigmaStar MI_GFX/MI_AO, no fbdev/X11) — SDL2 must be told explicitly or
# SDL_Init falls through with "No available video device".
export SDL_VIDEODRIVER=mmiyoo
export SDL_AUDIODRIVER=mmiyoo

# We now link against our own patched libSDL2 (./lib/libSDL2-2.0.so.0, takes
# priority over the stock one in .tmp_update via LD_LIBRARY_PATH order) which
# fixes the "mmiyoo" render backend's 10-texture cap and no-op QueueCopyEx/
# QueueFillRects — the earlier hard crash with this forced was against the
# device's *stock* SDL2, not this build. See PROJECT_STATUS.md.
export SDL_RENDER_DRIVER=mmiyoo

# OnionOS's own audioserver holds the MI_AO device open exclusively, so any app
# opening it directly (as our native SDL2 audio backend does) fails with
# MI_AO_SetPubAttr error 0xa0052009. Same fix RetroArch ports use (KillAudioserver=1).
. /mnt/SDCARD/.tmp_update/script/stop_audioserver.sh

# Keep the CPU at its max stock clock instead of scaling down when idle
# (same trick RetroArch ports use via PerformanceMode=1). Not overclocking —
# just stops the "ondemand"-style governor from throttling during gameplay.
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true

# Keep the previous run's log: a crash is usually noticed only after the game
# has been restarted, which used to truncate the very log that explained it.
[ -f log.txt ] && mv -f log.txt log.prev.txt

# Run openclaw and record log
./openclaw > log.txt 2>&1
EXIT_CODE=$?

# Post-mortem. The shell's own "Killed"/"Segmentation fault" notice is not
# reliably visible (and log.txt's tail is lost entirely if the device is hard
# reset before the kernel flushes its page cache), so record the exit status
# and the kernel ring buffer ourselves: an OOM kill leaves an unmistakable
# "Out of memory: Kill process ... (openclaw)" line in dmesg. Exit code 137 =
# SIGKILL (128+9, what the OOM killer sends), 139 = SIGSEGV.
{
    echo ""
    echo "=== openclaw exited, code $EXIT_CODE (137=SIGKILL/OOM, 139=SIGSEGV) ==="
    echo "--- free ---"
    free -m
    echo "--- dmesg tail ---"
    dmesg | tail -40
} >> log.txt 2>&1

# Archive anything that did not exit cleanly, so several crashes in a row can be
# compared instead of overwriting each other, and so the report survives the next
# launch. Kept to the last 10 to bound SD card usage.
#
# Two files per crash:
#   crashlogs/crash-<stamp>-report.txt  - small, self-contained, this is the one
#                                         to attach to a bug report
#   crashlogs/crash-<stamp>-log.txt     - the full log, useful but bulky
if [ "$EXIT_CODE" != "0" ]; then
    mkdir -p crashlogs
    STAMP=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)

    # Round the report out with the context only the shell has: how the process
    # died, how much memory was left, and what the kernel logged (an
    # out-of-memory kill says so there and nowhere else). Written even when the
    # game left no report of its own - a SIGKILL from the OOM killer cannot be
    # caught in-process, and that case still needs a file to attach.
    {
        if [ -f crash-report.txt ]; then
            cat crash-report.txt
        else
            echo "=== no in-process crash report (killed from outside?) ==="
            head -1 log.txt
        fi
        echo ""
        echo "--- exit ---"
        echo "exit code $EXIT_CODE (137=SIGKILL/out of memory, 139=SIGSEGV)"
        echo "--- free ---"
        free -m
        echo "--- kernel log (filtered) ---"
        dmesg | grep -i -E "openclaw|out of memory|oom" | tail -10
        echo ""
        echo "--- last 40 log lines ---"
        grep -v "^=== CRASH" log.txt | tail -40
    } > "crashlogs/crash-$STAMP-report.txt" 2>&1
    rm -f crash-report.txt

    cp -f log.txt "crashlogs/crash-$STAMP-log.txt"
    ls -1t crashlogs/crash-* 2>/dev/null | tail -n +21 | while read -r OLD; do rm -f "$OLD"; done
fi

# stdio line buffering only pushes each line into the kernel page cache; without
# this the last seconds of log.txt never reach the SD card if power is cut.
sync
