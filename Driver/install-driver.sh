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
if [ -d "$DEST/SilkMicDriver.driver" ]; then
  echo "SilkMic driver installed. The \"SilkMic\" mic appears while the SilkMic app is running."
else
  echo "SilkMic driver did NOT install. Check Console.app for coreaudiod plug-in errors."
  exit 1
fi
