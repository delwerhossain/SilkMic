#!/bin/bash
# Builds a release DMG of SilkMic without an Apple Developer ID: Release build, the virtual-mic
# driver bundled inside the app (installed by the app on first launch), ad-hoc signature, and a
# drag-to-Applications disk image. Used locally and by .github/workflows/release.yml.
#
#   scripts/build-dmg.sh            # version from the Xcode project
#   scripts/build-dmg.sh 1.0.0      # override the version
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(grep -m1 'MARKETING_VERSION' SilkMic.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/')}"
BUILD="build/release"
APP="$BUILD/Build/Products/Release/SilkMic.app"
DMG="build/SilkMic-$VERSION.dmg"

echo "==> SilkMic $VERSION"
rm -rf "$BUILD" "$DMG"

echo "==> Building the virtual mic driver"
Driver/build-driver.sh >/dev/null

echo "==> Building the app (Release)"
xcodebuild -project SilkMic.xcodeproj -scheme SilkMic -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$BUILD" \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  build | grep -E ' error:|BUILD (SUCCEEDED|FAILED)'

echo "==> Bundling the driver and signing (ad-hoc)"
cp -R Driver/build/SilkMicDriver.driver "$APP/Contents/Resources/"
codesign --force --deep --sign - --entitlements SilkMic/SilkMic.entitlements "$APP"
codesign --verify --deep --strict "$APP"

echo "==> Creating the disk image"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "SilkMic $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "==> $DMG"
