#!/bin/bash
# Build SilkMic (Release by default, CONFIG=Debug for debugging) and install it as a real app (/Applications if the DMG copy is there, else ~/Applications)
# (notifications, Login Items and permissions do not work for apps run from DerivedData).
set -euo pipefail
cd "$(dirname "$0")/.."
DD="${DERIVED_DATA:-build/DerivedData}"
# Release by default: a Debug build's audio path runs several times slower, so it misleads
# anyone judging SilkMic's CPU use.
CONFIG="${CONFIG:-Release}"
xcodebuild -project SilkMic.xcodeproj -scheme SilkMic -configuration "$CONFIG" \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DD" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build | grep -E ' error:|BUILD (SUCCEEDED|FAILED)'
pkill -x SilkMic 2>/dev/null || true
sleep 1
# One copy only: two copies with the same bundle ID confuse macOS permissions and login items.
# Use /Applications when SilkMic is installed there (from the DMG), else ~/Applications.
if [[ -d /Applications/SilkMic.app ]]; then DEST=/Applications/SilkMic.app; else DEST="$HOME/Applications/SilkMic.app"; fi
[[ "$DEST" == /Applications/SilkMic.app ]] && rm -rf "$HOME/Applications/SilkMic.app"
rm -rf "$DEST"
cp -R "$DD/Build/Products/$CONFIG/SilkMic.app" "$DEST"
# Same certificate as releases (if present), so permissions survive rebuilds.
IDENTITY="$(security find-identity -p codesigning 2>/dev/null | awk '/"SilkMic Self-Signed"/ {print $2; exit}')"
[[ -n "$IDENTITY" ]] && codesign --force --deep --sign "$IDENTITY" --entitlements SilkMic/SilkMic.entitlements "$DEST" 2>/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
open "$DEST"
echo "Installed and launched $DEST"
