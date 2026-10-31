#!/bin/bash
# Removes the SilkMic virtual mic. Needs the admin password; all audio drops briefly.
set -euo pipefail
DEST="/Library/Audio/Plug-Ins/HAL/SilkMicDriver.driver"
sudo rm -rf "$DEST"
sudo killall coreaudiod 2>/dev/null || true
echo "Removed SilkMic virtual mic. (Audio dropped briefly to restart coreaudiod.)"
