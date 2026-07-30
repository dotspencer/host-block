#!/bin/bash
# Builds HostBlock.app into dist/.
#   (no args)  fast ad-hoc signed build for local dev / screenshots
#   --release  Developer ID sign + hardened runtime + notarize + staple + DMG
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="1.0.9"
BUILD="1"
IDENTITY="Developer ID Application: Spencer Smith (BVXWVLHLQJ)"
NOTARY_PROFILE="hostblock notarization"
# Public base URL of the R2 releases folder (where the DMG is uploaded).
RELEASE_URL_BASE="https://updates.hostblock.app/releases"

RELEASE=0
[[ "${1:-}" == "--release" ]] && RELEASE=1

swift build -c release

APP="dist/HostBlock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/HostBlock "$APP/Contents/MacOS/HostBlock"

# Copy SwiftPM resource bundles (e.g. HostBlock_HostBlockCore.bundle holding
# catalog-fallback.json) so Bundle.module resolves them from Contents/Resources.
for bundle in .build/release/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

# App icon (Finder / DMG window / Get Info). Regenerate with scripts/make-icon.sh.
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>HostBlock</string>
    <key>CFBundleDisplayName</key><string>HostBlock</string>
    <key>CFBundleIdentifier</key><string>com.hostblock.app</string>
    <key>CFBundleExecutable</key><string>HostBlock</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

if [[ $RELEASE -eq 0 ]]; then
    # Ad-hoc signature so the bundle runs locally without Gatekeeper fuss.
    codesign --force --sign - "$APP"
    echo "Built (ad-hoc, local dev): $APP"
    exit 0
fi

# ---- Release: Developer ID signing + notarization + DMG --------------------

echo "==> Signing (Developer ID, hardened runtime)"
# The SwiftPM ".bundle" is a resource-only folder (no executable), so it isn't
# signed on its own — signing the app seals it as a resource.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Notarizing the app"
ZIP="dist/HostBlock.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$ZIP"
xcrun stapler staple "$APP"

echo "==> Building DMG"
DMG="dist/HostBlock-$VERSION.dmg"
STAGE="dist/dmg-stage"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "HostBlock" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
# Sign the DMG itself (before notarizing) so Gatekeeper assessment is unambiguous.
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing the DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Writing update feed (latest.json)"
# The app polls this to offer an "Update available" link. It lives alongside the DMG
# under releases/ (served at $RELEASE_URL_BASE/latest.json).
cat > dist/latest.json <<EOF
{
  "version": "$VERSION",
  "url": "$RELEASE_URL_BASE/HostBlock-$VERSION.dmg"
}
EOF

echo "==> Gatekeeper verification"
spctl -a -vvv "$APP" || true
spctl -a -t open --context context:primary-signature -vv "$DMG" || true

echo
echo "Release built + notarized: $DMG"
echo "Upload both to the 'hostblock' R2 bucket under releases/:"
echo "  • $(basename "$DMG")"
echo "  • latest.json"
