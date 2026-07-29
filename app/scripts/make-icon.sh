#!/bin/bash
# Regenerates Resources/AppIcon.icns from the shield motif. Run after changing
# make-icon.swift; the resulting .icns is committed and consumed by build-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift scripts/make-icon.swift "$ICONSET"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$(dirname "$ICONSET")"
echo "Wrote Resources/AppIcon.icns"
