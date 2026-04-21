#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_DIR="$ROOT_DIR/.build/FlowSound.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

if [[ -f "FlowSound-iCon.png" ]]; then
    scripts/generate-logo-assets.swift
    iconutil -c icns -o "Assets/FlowSound.icns" "Assets/FlowSound.iconset"
fi

swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/$CONFIGURATION/FlowSound" "$MACOS_DIR/FlowSound"
cp "packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -f "FlowSound-iCon.png" ]]; then
    cp "FlowSound-iCon.png" "$RESOURCES_DIR/FlowSound-iCon.png"
fi

if [[ -d "Assets" ]]; then
    cp Assets/*.png "$RESOURCES_DIR/"
fi

if [[ -f "Assets/FlowSound.icns" ]]; then
    cp "Assets/FlowSound.icns" "$RESOURCES_DIR/FlowSound.icns"
fi

codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
