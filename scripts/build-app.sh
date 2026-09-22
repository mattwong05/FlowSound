#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/release-common.sh"
CONFIGURATION="${1:-debug}"
ARCHITECTURES="${ARCHITECTURES:-universal}"
APP_DIR="${APP_OUTPUT_DIR:-$ROOT_DIR/.build/FlowSound.app}"
[[ $# -le 1 ]] || { fail 'Usage: build-app.sh [debug|release]'; exit 1; }
read_version
validate_build_options
plutil -lint "$ROOT_DIR/packaging/FlowSound.entitlements"
"$ROOT_DIR/scripts/check-toolchain.sh"
SELECTED_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SELECTED_SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
MINIMUM_SYSTEM_VERSION=15.0
normalize_version() {
    [[ "$1" =~ '^[0-9]+(\.[0-9]+)*$' ]] || { fail 'Invalid Mach-O or SDK version.'; return 1; }
    print -r -- "$1" | awk -F. '{
        last = NF
        while (last > 1 && $last == 0) last--
        for (i = 1; i <= last; i++) printf "%s%d", (i == 1 ? "" : "."), $i
    }'
}
EXPECTED_SDK_VERSION="$(normalize_version "$SELECTED_SDK_VERSION")"
EXPECTED_MINIMUM_VERSION="$(normalize_version "$MINIMUM_SYSTEM_VERSION")"
[[ ! -L "$APP_DIR" ]] || { fail 'App output must not be a symbolic link.'; exit 1; }
mkdir -p "${APP_DIR:h}"
STAGING_DIR="$(mktemp -d "${APP_DIR:h}/.flowsound-build.XXXXXX")"
BACKUP_DIR=''
cleanup() {
    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR/FlowSound.app" && ! -e "$APP_DIR" ]]; then
        mv "$BACKUP_DIR/FlowSound.app" "$APP_DIR"
    fi
    rm -rf "$STAGING_DIR"
    [[ -z "$BACKUP_DIR" ]] || rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

STAGED_APP="$STAGING_DIR/FlowSound.app"
MACOS_DIR="$STAGED_APP/Contents/MacOS"
RESOURCES_DIR="$STAGED_APP/Contents/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
BINARIES=()
for architecture in "${BUILD_ARCHITECTURES[@]}"; do
    BUILD_OPTIONS=(--package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/.build/packaging-$architecture" \
        --triple "$architecture-apple-macosx$MINIMUM_SYSTEM_VERSION" -c "$CONFIGURATION" \
        -Xswiftc -Xclang-linker -Xswiftc -isysroot \
        -Xswiftc -Xclang-linker -Xswiftc "$SELECTED_SDK_PATH")
    # Explicit Clang sysroot arguments survive SwiftBuild's environment filtering
    # and enter the link command's cache key. SDKROOT also covers native SwiftPM.
    SDKROOT="$SELECTED_SDK_PATH" swift build "${BUILD_OPTIONS[@]}" --product FlowSound
    BIN_PATH="$(SDKROOT="$SELECTED_SDK_PATH" swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
    BINARIES+=("$BIN_PATH/FlowSound")
done
if [[ ${#BINARIES} -eq 1 ]]; then
    cp "$BINARIES[1]" "$MACOS_DIR/FlowSound"
else
    xcrun lipo -create "${BINARIES[@]}" -output "$MACOS_DIR/FlowSound"
fi
ACTUAL_ARCHITECTURES=(${(s: :)$(xcrun lipo -archs "$MACOS_DIR/FlowSound")})
ACTUAL_ARCHITECTURES=(${(o)ACTUAL_ARCHITECTURES})
[[ "${ACTUAL_ARCHITECTURES[*]}" == "${BUILD_ARCHITECTURES[*]}" ]] || {
    fail 'Built Mach-O architectures do not match the requested architectures.'; exit 1
}
for architecture in "${BUILD_ARCHITECTURES[@]}"; do
    BUILD_VERSION_INFO="$(xcrun vtool -arch "$architecture" -show-build "$MACOS_DIR/FlowSound")"
    RECORDED_SDK_VERSION="$(print -r -- "$BUILD_VERSION_INFO" | awk '$1 == "sdk" { print $2 }')"
    RECORDED_MINIMUM_VERSION="$(print -r -- "$BUILD_VERSION_INFO" | awk '$1 == "minos" { print $2 }')"
    [[ "$(normalize_version "$RECORDED_SDK_VERSION")" == "$EXPECTED_SDK_VERSION" ]] || {
        fail "$architecture Mach-O SDK does not match selected macOS SDK $SELECTED_SDK_VERSION. Re-link with the selected SDK before packaging."; exit 1
    }
    [[ "$(normalize_version "$RECORDED_MINIMUM_VERSION")" == "$EXPECTED_MINIMUM_VERSION" ]] || {
        fail "$architecture Mach-O minimum target does not match macOS $MINIMUM_SYSTEM_VERSION."; exit 1
    }
done
sed "s/__FLOWSOUND_VERSION__/$VERSION/g" "$ROOT_DIR/packaging/Info.plist" > "$STAGED_APP/Contents/Info.plist"
plutil -lint "$STAGED_APP/Contents/Info.plist"

# Assets are checked in. Regenerate them explicitly when artwork changes;
# packaging must not modify source-controlled files.
[[ ! -f "$ROOT_DIR/FlowSound-iCon.png" ]] || cp "$ROOT_DIR/FlowSound-iCon.png" "$RESOURCES_DIR/"
for asset in "$ROOT_DIR"/Assets/*.png(N) "$ROOT_DIR"/Assets/*.icns(N); do
    cp "$asset" "$RESOURCES_DIR/"
done
codesign --force --entitlements "$ROOT_DIR/packaging/FlowSound.entitlements" --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

# Retain the previous local bundle if building or validation fails.
if [[ -e "$APP_DIR" ]]; then
    BACKUP_DIR="$(mktemp -d "${APP_DIR:h}/.flowsound-previous.XXXXXX")"
    mv "$APP_DIR" "$BACKUP_DIR/FlowSound.app"
fi
mv "$STAGED_APP" "$APP_DIR"
print -- "$APP_DIR"
