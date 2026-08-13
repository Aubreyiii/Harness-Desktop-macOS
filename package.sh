#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
VERSION="${VERSION:-0.2.0}"
ARCH="${ARCH:-$(uname -m)}"
APP="$BUILD/Harness Desktop.app"
STAGE="$BUILD/dmg-stage"
DMG="$BUILD/Harness-Desktop-macOS-${VERSION}-${ARCH}.dmg"
ZIP="$BUILD/Harness-Desktop-macOS-${VERSION}-${ARCH}.zip"

bash "$ROOT/build.sh"

rm -rf "$STAGE"
mkdir -p "$STAGE"
/usr/bin/ditto "$APP" "$STAGE/Harness Desktop.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG" "$ZIP"
/usr/bin/hdiutil create \
  -volname "Harness Desktop" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
/usr/bin/shasum -a 256 "$DMG" "$ZIP" > "$BUILD/SHA256SUMS.txt"

printf '%s\n%s\n%s\n' "$DMG" "$ZIP" "$BUILD/SHA256SUMS.txt"
