#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP_NAME="TaskBar"
APP="$DIST/${APP_NAME}.app"
ICON_SRC="${1:-}"
VERSION="1.2.0"
BUNDLE_ID="app.simpletaskbar.liquidglass"

cd "$ROOT"

echo "==> swift build -c release"
swift build -c release --product TaskBar

BIN="$ROOT/.build/release/TaskBar"
if [[ ! -x "$BIN" ]]; then
  echo "error: missing $BIN" >&2
  exit 1
fi

echo "==> assemble ${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/TaskBar"
chmod +x "$APP/Contents/MacOS/TaskBar"

cp "$ROOT/Sources/TaskBar/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"

if [[ -n "$ICON_SRC" && -f "$ICON_SRC" ]]; then
  echo "==> build AppIcon.icns"
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> ad-hoc codesign"
codesign --force --deep --sign - "$APP"

echo ""
echo "Done: $APP"
