#!/bin/bash
# Copies the canonical catalog (site/public/catalog.json, the same file served at
# https://hostblock.app/catalog.json) into the app as its bundled fallback.
# Run by scripts/build-app.sh before `swift build`; run it by hand after a fresh
# clone, since the destination is generated and not checked in.
#
# It lives in app/Resources (copied into Contents/Resources by build-app.sh and read
# through Bundle.main) rather than being declared as a SwiftPM `resources:` target.
# SwiftPM would route it through Bundle.module, whose generated accessor looks beside
# the .app instead of inside Contents/Resources, and falls back to an absolute path
# from the build machine that it bakes into the binary.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="../site/public/catalog.json"
DST="Resources/catalog-fallback.json"

if [[ ! -f "$SRC" ]]; then
    echo "sync-catalog: missing $SRC (the single source of truth)" >&2
    exit 1
fi

# Fail loudly on malformed JSON rather than shipping a fallback the app can't decode.
# (plutil can't lint a top-level JSON array, hence python3.)
if command -v python3 >/dev/null; then
    if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SRC"; then
        echo "sync-catalog: $SRC is not valid JSON" >&2
        exit 1
    fi
fi

cp "$SRC" "$DST"
echo "sync-catalog: $SRC -> app/$DST"
