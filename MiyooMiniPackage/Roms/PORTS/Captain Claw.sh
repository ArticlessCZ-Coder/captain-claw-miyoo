#!/bin/sh
# OnionOS Launcher script for Captain Claw (OpenClaw)

PORTRUN_DIR="/mnt/SDCARD/Roms/PORTS/Captain Claw"
cd "$PORTRUN_DIR"

# Ensure execution rights
chmod +x ./openclaw

# Create log file
echo "Starting Captain Claw..." > log.txt

# Export library path
export LD_LIBRARY_PATH="$PORTRUN_DIR:$PORTRUN_DIR/lib:$LD_LIBRARY_PATH"

# Run OpenClaw
./openclaw >> log.txt 2>&1
