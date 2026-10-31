#!/bin/bash
# Builds Driver/build/SilkMicDriver.driver (ad-hoc signed HAL plug-in).
set -euo pipefail
cd "$(dirname "$0")"
DRIVER="build/SilkMicDriver.driver"
SRC="SilkMicDriver"
rm -rf "$DRIVER"
mkdir -p "$DRIVER/Contents/MacOS"
cp "$SRC/Info.plist" "$DRIVER/Contents/Info.plist"
clang -bundle -std=c11 -fblocks -O2 -arch arm64 \
  -framework CoreAudio -framework CoreFoundation -framework AudioToolbox \
  "$SRC/SilkMicDriver.c" "$SRC/nn_ring.c" "$SRC/nn_clock.c" \
  -o "$DRIVER/Contents/MacOS/SilkMicDriver"
# Sign AFTER the bundle is fully assembled — any post-sign edit invalidates the signature and the
# plug-in then silently fails to load in coreaudiod.
codesign --force --sign - "$DRIVER"
codesign -dv --verbose=4 "$DRIVER" 2>&1 | sed -n '1,6p'
echo "Built $DRIVER"
