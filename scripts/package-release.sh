#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$ROOT_DIR/.build/FlowSound.app"
ARCHIVE_NAME="FlowSound-$VERSION.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
RELEASE_NOTES_PATH="$DIST_DIR/RELEASE_NOTES.md"
RELEASE_NOTES_TEMPLATE="$ROOT_DIR/docs/RELEASE_NOTES_TEMPLATE.md"
CHANGELOG_EXCERPT_PATH="$DIST_DIR/CHANGELOG_EXCERPT.md"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-0}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

cd "$ROOT_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

scripts/build-app.sh "$CONFIGURATION"

BUNDLE_SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
BUNDLE_BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist")"

if [[ "$BUNDLE_SHORT_VERSION" != "$VERSION" || "$BUNDLE_BUILD_VERSION" != "$VERSION" ]]; then
    echo "Bundle version mismatch: VERSION=$VERSION, CFBundleShortVersionString=$BUNDLE_SHORT_VERSION, CFBundleVersion=$BUNDLE_BUILD_VERSION." >&2
    exit 1
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing FlowSound.app with identity: $SIGN_IDENTITY"
    codesign --force --deep --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
    echo "SIGN_IDENTITY is not set; building an unsigned archive."
fi

ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
    if [[ -z "$SIGN_IDENTITY" || -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
        echo "NOTARIZE=1 requires SIGN_IDENTITY, APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD." >&2
        exit 1
    fi

    echo "Submitting $ARCHIVE_NAME for notarization."
    xcrun notarytool submit "$ARCHIVE_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait

    echo "Stapling notarization ticket."
    xcrun stapler staple "$APP_DIR"
    rm -f "$ARCHIVE_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"
fi

(
    cd "$DIST_DIR"
    shasum -a 256 "$ARCHIVE_NAME" > "$CHECKSUM_PATH"
)

awk -v version="$VERSION" '
    $0 ~ "^## \\[" version "\\]" { found = 1; next }
    found && $0 ~ "^## \\[" { exit }
    found { print }
' "$ROOT_DIR/CHANGELOG.md" > "$CHANGELOG_EXCERPT_PATH"

if [[ ! -s "$CHANGELOG_EXCERPT_PATH" ]]; then
    echo "CHANGELOG.md does not contain a release section for $VERSION." >&2
    exit 1
fi

sed "s/VERSION/$VERSION/g" "$RELEASE_NOTES_TEMPLATE" | while IFS= read -r line; do
    if [[ "$line" == "- Replace this section with the release changelog." ]]; then
        cat "$CHANGELOG_EXCERPT_PATH"
    else
        echo "$line"
    fi
done > "$RELEASE_NOTES_PATH"
rm -f "$CHANGELOG_EXCERPT_PATH"

echo "$ARCHIVE_PATH"
echo "$CHECKSUM_PATH"
echo "$RELEASE_NOTES_PATH"
