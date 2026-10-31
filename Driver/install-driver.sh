#!/bin/bash
# Installs the SilkMic virtual mic. Needs the admin password; all audio drops briefly.
set -euo pipefail
cd "$(dirname "$0")"
DRIVER="build/SilkMicDriver.driver"
DEST="/Library/Audio/Plug-Ins/HAL"
[ -d "$DRIVER" ] || { echo "Build first: ./build-driver.sh"; exit 1; }
echo "Installing to $DEST (requires admin; ALL audio will briefly drop on coreaudiod restart)…"
sudo rm -rf "$DEST/SilkMicDriver.driver"
sudo cp -R "$DRIVER" "$DEST/"
sudo xattr -dr com.apple.quarantine "$DEST/SilkMicDriver.driver" 2>/dev/null || true
sudo killall coreaudiod 2>/dev/null || true
sleep 3
if system_profiler SPAudioDataType 2>/dev/null | grep -q "SilkMic:"; then
  echo "SilkMic virtual mic installed and visible."
else
  echo "SilkMic virtual mic did NOT appear. Check Console.app for coreaudiod plug-in errors"
  echo "(common causes: bad CFPlugInFactories/CFPlugInTypes keys, invalid signature)."
  exit 1
fi
