#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
PREVIEW_DIR="$ROOT_DIR/.build/ui-preview"
APP_DIR="$PREVIEW_DIR/FlowSoundPreview.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
SOURCES=()
for source in "$ROOT_DIR"/Sources/FlowSound/*.swift; do
    [[ "${source:t}" == main.swift ]] || SOURCES+=("$source")
done
SELECTED_SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 6 -target "$(uname -m)-apple-macos15.0" \
    -Xclang-linker -isysroot -Xclang-linker "$SELECTED_SDK" \
    "${SOURCES[@]}" "$ROOT_DIR/scripts/preview-ui.swift" -o "$APP_DIR/Contents/MacOS/FlowSoundPreview"
VERSION="$(tr -d '[:space:]' < VERSION)"
sed "s/__FLOWSOUND_VERSION__/$VERSION/g" packaging/Info.plist > "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable FlowSoundPreview' "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.flowsound.DesignPreview' "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName FlowSound Preview' "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :LSUIElement false' "$APP_DIR/Contents/Info.plist"
cp Assets/*.icns Assets/*.png "$APP_DIR/Contents/Resources/"
codesign --force --sign - "$APP_DIR"
"$APP_DIR/Contents/MacOS/FlowSoundPreview"
