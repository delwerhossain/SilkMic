#!/bin/bash
# Build SilkMic (Debug) and install it to ~/Applications so macOS treats it as a real app
# (notifications, Login Items and permissions do not work for apps run from DerivedData).
set -euo pipefail
cd "$(dirname "$0")/.."
DD="${DERIVED_DATA:-build/DerivedData}"
xcodebuild -project SilkMic.xcodeproj -scheme SilkMic -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DD" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build | grep -E ' error:|BUILD (SUCCEEDED|FAILED)'
pkill -x SilkMic 2>/dev/null || true
sleep 1
rm -rf ~/Applications/SilkMic.app
cp -R "$DD/Build/Products/Debug/SilkMic.app" ~/Applications/SilkMic.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/SilkMic.app
open ~/Applications/SilkMic.app
echo "Installed and launched ~/Applications/SilkMic.app"
