#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/release-common.sh"
CONFIGURATION="${CONFIGURATION:-release}"
ARCHITECTURES="${ARCHITECTURES:-universal}"
RELEASE_CHANNEL="${RELEASE_CHANNEL:-test}"
RELEASE_TAG="${RELEASE_TAG:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-0}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
[[ $# == 0 || ( $# == 1 && "$1" == --check ) ]] || { fail 'Usage: package-release.sh [--check]'; exit 1; }

# Validate all release inputs before touching any existing output or building.
validate_release_options
"$ROOT_DIR/scripts/check-toolchain.sh"
DIST_DIR="$ROOT_DIR/dist/$VERSION"
OUTPUT_DIR="$DIST_DIR/$RELEASE_CHANNEL"
[[ ! -e "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]] || {
    fail "Output already exists at $OUTPUT_DIR. Move it aside explicitly before rebuilding."; exit 1
}
if [[ "${1:-}" == --check ]]; then
    print -- "Release preflight passed: $VERSION ($RELEASE_CHANNEL, $ARCHITECTURES). No artifacts created."
    exit 0
fi

mkdir -p "$DIST_DIR"
LOCK_DIR="$DIST_DIR/.$RELEASE_CHANNEL.lock"
mkdir "$LOCK_DIR" || { fail 'Another packaging operation owns the output lock.'; exit 1; }
STAGING_DIR=''
cleanup() {
    [[ -z "$STAGING_DIR" ]] || rm -rf "$STAGING_DIR"
    rmdir "$LOCK_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
[[ ! -e "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]] || { fail 'Output appeared while acquiring the lock.'; exit 1; }
STAGING_DIR="$(mktemp -d "$DIST_DIR/.$RELEASE_CHANNEL.XXXXXX")"
APP_DIR="$STAGING_DIR/FlowSound.app"
ARTIFACT_DIR="$STAGING_DIR/output"
mkdir "$ARTIFACT_DIR"
ARCHIVE_NAME="FlowSound-$VERSION.zip"
ARCHIVE_PATH="$ARTIFACT_DIR/$ARCHIVE_NAME"
APP_OUTPUT_DIR="$APP_DIR" ARCHITECTURES="$ARCHITECTURES" "$ROOT_DIR/scripts/build-app.sh" "$CONFIGURATION"

for version_key in CFBundleShortVersionString CFBundleVersion; do
    [[ "$(/usr/libexec/PlistBuddy -c "Print :$version_key" "$APP_DIR/Contents/Info.plist")" == "$VERSION" ]] || {
        fail "Bundle $version_key does not match VERSION."; exit 1
    }
done
if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --timestamp --options runtime \
        --entitlements "$ROOT_DIR/packaging/FlowSound.entitlements" --sign "$SIGN_IDENTITY" "$APP_DIR"
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
    codesign --display --entitlements :- "$APP_DIR" > "$STAGING_DIR/signed-entitlements.plist" 2>/dev/null
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.automation.apple-events' "$STAGING_DIR/signed-entitlements.plist")" == true ]] || {
        fail 'Signed app is missing the Apple Events entitlement.'; exit 1
    }
else
    print 'Building an ad-hoc signed test archive; public distribution requires RELEASE_CHANNEL=stable.'
fi
ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"
if [[ "$NOTARIZE" == 1 ]]; then
    if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
        xcrun notarytool submit "$ARCHIVE_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    else
        xcrun notarytool submit "$ARCHIVE_PATH" --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --wait
    fi
    xcrun stapler staple "$APP_DIR"
    xcrun stapler validate "$APP_DIR"
    spctl --assess --type execute "$APP_DIR"
    rm "$ARCHIVE_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"
fi
(
    cd "$ARTIFACT_DIR"
    shasum -a 256 "$ARCHIVE_NAME" > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)
sed "s/VERSION/$VERSION/g" "$ROOT_DIR/docs/RELEASE_NOTES_TEMPLATE.md" | while IFS= read -r line; do
    if [[ "$line" == '- Replace this section with the release changelog.' ]]; then
        print -r -- "$RELEASE_CHANGELOG"
    else
        print -r -- "$line"
    fi
done > "$ARTIFACT_DIR/RELEASE_NOTES.md"
{
    print -- "Version: $VERSION"
    print -- "Channel: $RELEASE_CHANNEL"
    print -- "Architectures: $(xcrun lipo -archs "$APP_DIR/Contents/MacOS/FlowSound")"
    print -- "Selected macOS SDK: $(xcrun --sdk macosx --show-sdk-version)"
    for architecture in "${BUILD_ARCHITECTURES[@]}"; do
        BUILD_VERSION_INFO="$(xcrun vtool -arch "$architecture" -show-build "$APP_DIR/Contents/MacOS/FlowSound")"
        print -- "$architecture SDK: $(print -r -- "$BUILD_VERSION_INFO" | awk '$1 == "sdk" { print $2 }')"
        print -- "$architecture minimum target: $(print -r -- "$BUILD_VERSION_INFO" | awk '$1 == "minos" { print $2 }')"
    done
    print -- "Configuration: $CONFIGURATION"
    print -- "Notarized: $NOTARIZE"
    xcodebuild -version
    swift --version 2>&1
} > "$ARTIFACT_DIR/BUILD_INFO.txt"

# One same-filesystem rename publishes the complete artifact set. Existing
# releases are never overwritten, including when a build fails or is cancelled.
mv "$ARTIFACT_DIR" "$OUTPUT_DIR"
print -- "$OUTPUT_DIR"
