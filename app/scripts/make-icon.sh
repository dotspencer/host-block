#!/bin/bash
# Regenerates Resources/AppIcon.icns from the shield motif. Run after changing
# make-icon.swift; the resulting .icns is committed and consumed by build-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift scripts/make-icon.swift "$ICONSET"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
# Also keep a 1024px PNG for the website / store listing.
cp "$ICONSET/icon_512x512@2x.png" Resources/AppIcon.png
rm -rf "$(dirname "$ICONSET")"
echo "Wrote Resources/AppIcon.icns and Resources/AppIcon.png"
