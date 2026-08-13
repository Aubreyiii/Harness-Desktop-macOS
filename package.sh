#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
VERSION="${VERSION:-0.2.2}"
ARCH="${ARCH:-$(uname -m)}"
APP="$BUILD/Harness Desktop.app"
STAGE="$BUILD/dmg-stage"
RW_DMG="$BUILD/Harness-Desktop-layout-${ARCH}.dmg"
DMG="$BUILD/Harness-Desktop-macOS-${VERSION}-${ARCH}.dmg"
ZIP="$BUILD/Harness-Desktop-macOS-${VERSION}-${ARCH}.zip"
VOLUME="Harness Desktop"
MOUNT="$BUILD/dmg-mount"

bash "$ROOT/build.sh"

rm -rf "$STAGE" "$MOUNT"
mkdir -p "$STAGE" "$MOUNT"
/usr/bin/ditto "$APP" "$STAGE/Harness Desktop.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$RW_DMG" "$DMG" "$ZIP"
/usr/bin/hdiutil create \
  -volname "$VOLUME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG" >/dev/null

DEVICE="$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT" "$RW_DMG" | awk '/Apple_HFS/ {print $1; exit}')"
if [[ -z "$DEVICE" ]]; then
  echo "Unable to mount temporary DMG" >&2
  exit 1
fi

cleanup() {
  /usr/bin/hdiutil detach "$DEVICE" -quiet 2>/dev/null || true
}
trap cleanup EXIT

/usr/bin/python3 - "$MOUNT/.DS_Store" <<'PYDSSTORE'
import sys
from ds_store import DSStore
path = sys.argv[1]
with DSStore.open(path, 'w+') as store:
    store['.']['bwsp'] = {
        'ShowStatusBar': False,
        'ShowPathbar': False,
        'ShowToolbar': False,
        'SidebarWidth': 0,
        'ContainerShowSidebar': False,
        'WindowBounds': '{{120, 120}, {640, 400}}',
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1,
        'iconSize': 128.0,
        'textSize': 14.0,
        'arrangeBy': 'none',
        'gridOffsetX': 0.0,
        'gridOffsetY': 0.0,
        'gridSpacing': 100.0,
        'labelOnBottom': True,
        'showIconPreview': True,
        'showItemInfo': False,
    }
    store['Harness Desktop.app']['Iloc'] = (190, 190)
    store['Applications']['Iloc'] = (450, 190)
PYDSSTORE

/usr/bin/SetFile -a V "$MOUNT/.DS_Store"
/bin/sync
/usr/bin/hdiutil detach "$DEVICE" -quiet
trap - EXIT
DEVICE=""

/usr/bin/hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW_DMG"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
/usr/bin/shasum -a 256 "$DMG" "$ZIP" > "$BUILD/SHA256SUMS.txt"

printf '%s\n%s\n%s\n' "$DMG" "$ZIP" "$BUILD/SHA256SUMS.txt"
