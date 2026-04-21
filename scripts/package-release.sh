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

sed "s/VERSION/$VERSION/g" "$ROOT_DIR/docs/RELEASE_NOTES_TEMPLATE.md" > "$RELEASE_NOTES_PATH"

echo "$ARCHIVE_PATH"
echo "$CHECKSUM_PATH"
echo "$RELEASE_NOTES_PATH"
