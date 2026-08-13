#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Harness Desktop.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

/usr/bin/swiftc \
  -parse-as-library \
  -O \
  -framework AppKit \
  -framework WebKit \
  "$ROOT/Sources/main.swift" \
  -o "$MACOS/HarnessDesktop"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

echo "$APP"
