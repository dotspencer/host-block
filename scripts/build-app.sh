#!/bin/bash
# Builds HostBlock.app into dist/ from the SwiftPM release build.
set -euo pipefail
cd "$(dirname "$0")/.."

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

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>HostBlock</string>
    <key>CFBundleDisplayName</key>
    <string>HostBlock</string>
    <key>CFBundleIdentifier</key>
    <string>com.hostblock.app</string>
    <key>CFBundleExecutable</key>
    <string>HostBlock</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc signature so the bundle runs locally; replace with a Developer ID
# identity (and notarization) for distribution.
codesign --force --sign - "$APP"

echo "Built $APP"
