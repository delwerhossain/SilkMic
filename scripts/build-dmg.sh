#!/bin/bash
# Builds a release DMG of SilkMic without an Apple Developer ID: Release build, the virtual-mic
# driver bundled inside the app (installed by the app on first launch), and a designed
# drag-to-Applications disk image. Used locally and by .github/workflows/release.yml.
#
# Signing: uses the "SilkMic Self-Signed" certificate when it is in the keychain (or the identity
# in $SILKMIC_SIGN_IDENTITY). A fixed certificate keeps macOS permissions (microphone,
# Accessibility) across updates; an ad-hoc signature changes with every build, so macOS asks
# again after each update. Needs dmgbuild (`uv tool install dmgbuild` or `pip install dmgbuild`).
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

IDENTITY="${SILKMIC_SIGN_IDENTITY:-$(security find-identity -p codesigning 2>/dev/null | awk '/"SilkMic Self-Signed"/ {print $2; exit}')}"
IDENTITY="${IDENTITY:--}"
[[ "$IDENTITY" == "-" ]] && echo "==> No SilkMic signing certificate found: ad-hoc signature (permissions reset on update)"

echo "==> Bundling the driver and signing"
cp -R Driver/build/SilkMicDriver.driver "$APP/Contents/Resources/"
codesign --force --deep --sign "$IDENTITY" --entitlements SilkMic/SilkMic.entitlements "$APP"
codesign --verify --deep "$APP"
codesign -d -r- "$APP" 2>&1 | grep designated

echo "==> Creating the disk image"
dmgbuild -s scripts/dmg/settings.py -D app="$APP" "SilkMic $VERSION" "$DMG" >/dev/null

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "==> $DMG"
