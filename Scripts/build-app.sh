#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift Scripts/generate-icon.swift "$ROOT/Resources"
iconutil -c icns "$ROOT/Resources/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"
swift build -c release --product CleanDiskTrash
BIN_PATH="$(swift build -c release --product CleanDiskTrash --show-bin-path)"
APP="$ROOT/dist/CleanDisk.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/CleanDiskTrash" "$APP/Contents/MacOS/CleanDiskTrash"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/AppIcon.png" "$APP/Contents/Resources/AppIcon.png"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - --timestamp=none "$APP"

echo "$APP"
if [[ "${1:-}" == "--open" ]]; then
    open "$APP"
fi
