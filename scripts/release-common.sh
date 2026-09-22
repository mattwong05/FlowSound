#!/bin/zsh
# Shared validation only. Sourcing this file does not build, sign, or publish.

fail() {
    print -u2 -- "$*"
    return 1
}

read_version() {
    VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
    [[ "$VERSION" =~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] ||
        fail 'VERSION must use MAJOR.MINOR.PATCH SemVer format.'
}

validate_build_options() {
    [[ "$CONFIGURATION" == debug || "$CONFIGURATION" == release ]] ||
        fail 'CONFIGURATION must be debug or release.'
    case "$ARCHITECTURES" in
        universal) BUILD_ARCHITECTURES=(arm64 x86_64) ;;
        current) BUILD_ARCHITECTURES=("$(uname -m)") ;;
        *) fail 'ARCHITECTURES must be universal or current.'; return 1 ;;
    esac
    for architecture in "${BUILD_ARCHITECTURES[@]}"; do
        [[ "$architecture" == arm64 || "$architecture" == x86_64 ]] ||
            fail 'The current machine architecture is unsupported.'
    done
}

read_release_changelog() {
    RELEASE_CHANGELOG="$(awk -v heading="## [$VERSION]" '
        $0 == heading || index($0, heading " ") == 1 {
            count++; in_section = 1; next
        }
        /^## \[/ { in_section = 0 }
        in_section { text = text $0 "\n"; if ($0 ~ /^- .+/) has_entry = 1 }
        END {
            if (count != 1 || !has_entry) exit 1
            printf "%s", text
        }
    ' "$ROOT_DIR/CHANGELOG.md")" ||
        fail "CHANGELOG.md must contain exactly one nonempty release section for $VERSION."
}

validate_stable_source() {
    [[ "$RELEASE_TAG" == "v$VERSION" ]] || fail 'Stable RELEASE_TAG must equal vVERSION.'
    [[ "$(git -C "$ROOT_DIR" rev-parse "refs/tags/$RELEASE_TAG^{commit}" 2>/dev/null)" == \
       "$(git -C "$ROOT_DIR" rev-parse HEAD)" ]] || fail 'Release tag must point at the current commit.'
    git -C "$ROOT_DIR" merge-base --is-ancestor HEAD refs/remotes/origin/main ||
        fail 'Stable release commit must belong to origin/main; fetch origin/main before packaging.'
    [[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] || fail 'Stable packaging requires a clean working tree.'
}

validate_release_options() {
    read_version
    validate_build_options
    [[ "$RELEASE_CHANNEL" == test || "$RELEASE_CHANNEL" == stable ]] ||
        fail 'RELEASE_CHANNEL must be test or stable.'
    [[ "$NOTARIZE" == 0 || "$NOTARIZE" == 1 ]] || fail 'NOTARIZE must be 0 or 1.'
    [[ -z "$SIGN_IDENTITY" || "$SIGN_IDENTITY" == 'Developer ID Application: '* ]] ||
        fail 'Distribution signing requires a Developer ID Application identity.'
    read_release_changelog
    [[ -f "$ROOT_DIR/docs/RELEASE_NOTES_TEMPLATE.md" ]] || fail 'Release notes template is missing.'
    [[ "$(awk '$0 == "- Replace this section with the release changelog." { count++ } END { print count+0 }' \
        "$ROOT_DIR/docs/RELEASE_NOTES_TEMPLATE.md")" == 1 ]] || fail 'Release notes template must contain one changelog placeholder.'
    if [[ "$NOTARIZE" == 1 ]]; then
        [[ -n "$SIGN_IDENTITY" ]] || fail 'Notarization requires Developer ID signing.'
        [[ -n "$NOTARYTOOL_PROFILE" || ( -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ) ]] ||
            fail 'Notarization requires NOTARYTOOL_PROFILE or Apple ID, team ID, and app-specific password environment variables.'
    fi
    if [[ "$RELEASE_CHANNEL" == stable ]]; then
        [[ "$CONFIGURATION" == release && "$ARCHITECTURES" == universal ]] ||
            fail 'Stable packages require release configuration and universal architectures.'
        [[ -n "$SIGN_IDENTITY" && "$NOTARIZE" == 1 ]] || fail 'Stable packages require Developer ID signing and notarization.'
        validate_stable_source
    fi
}
