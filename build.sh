#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Harness Desktop.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
RUNTIME="$RESOURCES/runtime"
CACHE="$BUILD/cache"
RUNTIME_CACHE="$CACHE/runtime-${DSH_VERSION:-0.1.0-rc.6}-${ARCH:-$(uname -m)}"

DSH_VERSION="${DSH_VERSION:-0.1.0-rc.6}"
NODE_VERSION="${NODE_VERSION:-24.19.0}"
ARCH="${ARCH:-$(uname -m)}"

case "$ARCH" in
  arm64) NODE_ARCH="arm64" ;;
  x86_64) NODE_ARCH="x64" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

NODE_DIST="node-v${NODE_VERSION}-darwin-${NODE_ARCH}"
NODE_TARBALL="$CACHE/${NODE_DIST}.tar.gz"
NODE_DIR="$CACHE/$NODE_DIST"

mkdir -p "$BUILD" "$CACHE"
if [[ ! -x "$NODE_DIR/bin/node" ]]; then
  if [[ ! -f "$NODE_TARBALL" ]]; then
    /usr/bin/curl -fL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.gz" -o "$NODE_TARBALL"
  fi
  /usr/bin/tar -xzf "$NODE_TARBALL" -C "$CACHE"
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$RUNTIME/bin"

/usr/bin/swiftc \
  -target "${ARCH}-apple-macos13.0" \
  -parse-as-library \
  -O \
  -framework AppKit \
  -framework WebKit \
  "$ROOT/Sources/main.swift" \
  -o "$MACOS/HarnessDesktop"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$NODE_DIR/bin/node" "$RUNTIME/bin/node"

if [[ ! -f "$RUNTIME_CACHE/node_modules/@deepseek-ai/dsh/lib/bin.js" ]]; then
  mkdir -p "$RUNTIME_CACHE"
  PATH="$NODE_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$NODE_DIR/bin/npm" install \
    --prefix "$RUNTIME_CACHE" \
    --omit=dev \
    --no-audit \
    --no-fund \
    --ignore-scripts=false \
    "@deepseek-ai/dsh@$DSH_VERSION"
fi
/usr/bin/ditto "$RUNTIME_CACHE/node_modules" "$RUNTIME/node_modules"

test -f "$RUNTIME/node_modules/@deepseek-ai/dsh/lib/bin.js"

LICENSES="$RESOURCES/licenses"
mkdir -p "$LICENSES/node" "$LICENSES/dsh"
cp "$NODE_DIR/LICENSE" "$LICENSES/node/LICENSE"
while IFS= read -r license; do
  relative="${license#"$RUNTIME/node_modules/"}"
  destination="$LICENSES/dsh/$relative"
  mkdir -p "$(dirname "$destination")"
  cp "$license" "$destination"
done < <(find "$RUNTIME/node_modules" -type f \( -iname 'LICENSE' -o -iname 'LICENSE.*' -o -iname 'COPYING' -o -iname 'COPYING.*' \))
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$RESOURCES/THIRD_PARTY_NOTICES.md"

/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

echo "$APP"
