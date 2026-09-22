#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/flowsound-release-tests.XXXXXX")"
trap 'rm -rf "$FIXTURE"; rm -f "$FIXTURE-result.log"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$FIXTURE/scripts" "$FIXTURE/docs" "$FIXTURE/dist/previous"
cp "$ROOT_DIR/scripts/"{package-release.sh,release-common.sh} "$FIXTURE/scripts/"
printf 'previous artifact\n' > "$FIXTURE/dist/previous/keep.txt"
printf '1.2.3\n' > "$FIXTURE/VERSION"
printf '# Changelog\n\n## [1.2.3] - 2026-09-23\n\n### Fixed\n\n- Fixture change.\n' > "$FIXTURE/CHANGELOG.md"
printf '# FlowSound VERSION\n\n- Replace this section with the release changelog.\n' > "$FIXTURE/docs/RELEASE_NOTES_TEMPLATE.md"
printf 'dist/\n' > "$FIXTURE/.gitignore"
# Fixtures never inspect credentials, compile an app, sign, or contact a service.
printf '#!/bin/zsh\nexit 0\n' > "$FIXTURE/scripts/check-toolchain.sh"
printf '#!/bin/zsh\nexit 23\n' > "$FIXTURE/scripts/build-app.sh"
chmod +x "$FIXTURE/scripts/"*.sh

test_count=0
expect_failure() {
    local expected="$1"
    shift
    if "$@" > "$FIXTURE-result.log" 2>&1; then
        print -u2 -- "Expected failure containing: $expected"
        exit 1
    fi
    if ! /usr/bin/grep -Fq -- "$expected" "$FIXTURE-result.log"; then
        cat "$FIXTURE-result.log"
        print -u2 -- "Missing expected failure: $expected"
        exit 1
    fi
    rm "$FIXTURE-result.log"
    [[ "$(cat "$FIXTURE/dist/previous/keep.txt")" == 'previous artifact' ]]
    (( ++test_count ))
}
run_fixture() {
    env -i PATH="$PATH" \
        CONFIGURATION=release ARCHITECTURES=universal RELEASE_CHANNEL=test NOTARIZE=0 \
        "$@"
}
PACKAGE="$FIXTURE/scripts/package-release.sh"
run_fixture "$PACKAGE" --check > /dev/null
[[ ! -e "$FIXTURE/dist/1.2.3" ]]
(( ++test_count ))
expect_failure 'Usage:' run_fixture "$PACKAGE" --invalid
expect_failure 'CONFIGURATION must' run_fixture CONFIGURATION=fast "$PACKAGE" --check
expect_failure 'ARCHITECTURES must' run_fixture ARCHITECTURES=all "$PACKAGE" --check
expect_failure 'RELEASE_CHANNEL must' run_fixture RELEASE_CHANNEL=public "$PACKAGE" --check
expect_failure 'NOTARIZE must' run_fixture NOTARIZE=yes "$PACKAGE" --check
expect_failure 'Developer ID Application' run_fixture SIGN_IDENTITY='Apple Development: Fixture' "$PACKAGE" --check
expect_failure 'Stable RELEASE_TAG must' run_fixture RELEASE_CHANNEL=stable "$PACKAGE" --check
expect_failure 'Notarization requires Developer ID' run_fixture NOTARIZE=1 "$PACKAGE" --check
expect_failure 'Notarization requires NOTARYTOOL_PROFILE' run_fixture NOTARIZE=1 SIGN_IDENTITY='Developer ID Application: Fixture' "$PACKAGE" --check
printf '01.2.3\n' > "$FIXTURE/VERSION"
expect_failure 'SemVer' run_fixture "$PACKAGE" --check
printf '1.2.4\n' > "$FIXTURE/VERSION"
expect_failure 'nonempty release section' run_fixture "$PACKAGE" --check
printf '1.2.3\n' > "$FIXTURE/VERSION"
cp "$FIXTURE/CHANGELOG.md" "$FIXTURE/changelog-copy"
cat "$FIXTURE/changelog-copy" >> "$FIXTURE/CHANGELOG.md"
expect_failure 'exactly one nonempty' run_fixture "$PACKAGE" --check
mv "$FIXTURE/changelog-copy" "$FIXTURE/CHANGELOG.md"
mkdir -p "$FIXTURE/dist/1.2.3/test"
printf 'existing output\n' > "$FIXTURE/dist/1.2.3/test/keep.txt"
expect_failure 'Output already exists' run_fixture "$PACKAGE" --check
[[ "$(cat "$FIXTURE/dist/1.2.3/test/keep.txt")" == 'existing output' ]]
# Only remove this test-created output; the prior release sentinel remains.
rm "$FIXTURE/dist/1.2.3/test/keep.txt"
rmdir "$FIXTURE/dist/1.2.3/test"
if run_fixture "$PACKAGE" > /dev/null 2>&1; then
    print -u2 'A failed build must abort packaging.'; exit 1
fi
[[ ! -e "$FIXTURE/dist/1.2.3/test" && ! -e "$FIXTURE/dist/1.2.3/.test.lock" ]]
[[ "$(cat "$FIXTURE/dist/previous/keep.txt")" == 'previous artifact' ]]
(( ++test_count ))

# Validate the stable branch and tag contract against a local throwaway repo.
git -C "$FIXTURE" init -q -b main
git -C "$FIXTURE" add .
git -C "$FIXTURE" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'fixture'
git -C "$FIXTURE" tag v1.2.3
git -C "$FIXTURE" update-ref refs/remotes/origin/main HEAD
STABLE_ENV=(RELEASE_CHANNEL=stable RELEASE_TAG=v1.2.3 NOTARIZE=0)
run_fixture "${STABLE_ENV[@]}" "$PACKAGE" --check > /dev/null
(( ++test_count ))
SIGNED_STABLE_ENV=(RELEASE_CHANNEL=stable RELEASE_TAG=v1.2.3 NOTARIZE=1 \
    SIGN_IDENTITY='Developer ID Application: Fixture' NOTARYTOOL_PROFILE=fixture)
run_fixture "${SIGNED_STABLE_ENV[@]}" "$PACKAGE" --check > /dev/null
(( ++test_count ))
expect_failure 'Notarization requires Developer ID' run_fixture "${STABLE_ENV[@]}" NOTARIZE=1 "$PACKAGE" --check
expect_failure 'Notarization requires NOTARYTOOL_PROFILE' run_fixture "${STABLE_ENV[@]}" NOTARIZE=1 SIGN_IDENTITY='Developer ID Application: Fixture' "$PACKAGE" --check
expect_failure 'Stable RELEASE_TAG must' run_fixture "${STABLE_ENV[@]}" RELEASE_TAG=v1.2.4 "$PACKAGE" --check
expect_failure 'universal architectures' run_fixture "${STABLE_ENV[@]}" ARCHITECTURES=current "$PACKAGE" --check
printf '\nUncommitted fixture change\n' >> "$FIXTURE/CHANGELOG.md"
expect_failure 'clean working tree' run_fixture "${STABLE_ENV[@]}" "$PACKAGE" --check
git -C "$FIXTURE" add CHANGELOG.md
git -C "$FIXTURE" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'outside stable branch'
expect_failure 'tag must point' run_fixture "${STABLE_ENV[@]}" "$PACKAGE" --check
git -C "$FIXTURE" tag -f v1.2.3 > /dev/null
expect_failure 'must belong to origin/main' run_fixture "${STABLE_ENV[@]}" "$PACKAGE" --check

# Exercise the real bundle builder against fake compiler/linker output. This
# verifies SDKROOT propagation and rejects bad metadata before any signing.
cp "$ROOT_DIR/scripts/build-app.sh" "$FIXTURE/scripts/build-app.sh"
mkdir -p "$FIXTURE/packaging" "$FIXTURE/mock-bin" "$FIXTURE/mock-sdk" "$FIXTURE/mock-products" "$FIXTURE/previous.app"
cp "$ROOT_DIR/packaging/"{Info.plist,FlowSound.entitlements} "$FIXTURE/packaging/"
printf 'old bundle\n' > "$FIXTURE/previous.app/keep.txt"
cat > "$FIXTURE/mock-bin/swift" <<'MOCK'
#!/bin/zsh
set -euo pipefail
if [[ "$1" == --version ]]; then print 'Swift version fixture'; exit 0; fi
[[ "${SDKROOT:-}" == "$FLOWSOUND_FIXTURE/mock-sdk" ]] || { print -u2 'SDKROOT was not propagated'; exit 1; }
if [[ " $* " == *' --show-bin-path '* ]]; then
    print -- "$FLOWSOUND_FIXTURE/mock-products"
else
    printf 'fixture executable\n' > "$FLOWSOUND_FIXTURE/mock-products/FlowSound"
fi
MOCK
cat > "$FIXTURE/mock-bin/xcrun" <<'MOCK'
#!/bin/zsh
set -euo pipefail
case "$1 $2" in
    '--sdk macosx')
        if [[ "$3" == --show-sdk-path ]]; then print -- "$FLOWSOUND_FIXTURE/mock-sdk"
        else print 27.0; fi ;;
    'lipo -archs') print 'x86_64 arm64' ;;
    'lipo -create') cp "$3" "${@[-1]}" ;;
    'vtool -arch')
        print 'cmd LC_BUILD_VERSION'
        print -- "minos ${FIXTURE_MINIMUM_VERSION:-15.0.0}"
        if [[ "$3" == x86_64 ]]; then print -- "sdk ${FIXTURE_INTEL_SDK_VERSION:-27.0.0}"
        else print 'sdk 27.0'; fi ;;
    'notarytool submit') print -u2 'Fixture notarization failed'; exit 23 ;;
    *) exit 1 ;;
esac
MOCK
cat > "$FIXTURE/mock-bin/codesign" <<'MOCK'
#!/bin/zsh
print 'sign called' >> "$FLOWSOUND_FIXTURE/signing.log"
if [[ " $* " == *' --sign Developer ID Application: Fixture '* && "${FIXTURE_FAIL_SIGNING:-0}" == 1 ]]; then
    print -u2 'Fixture Developer ID signing failed'; exit 23
fi
if [[ "$1" == --display ]]; then
    cat "$FLOWSOUND_FIXTURE/packaging/FlowSound.entitlements"
fi
MOCK
cat > "$FIXTURE/mock-bin/xcodebuild" <<'MOCK'
#!/bin/zsh
print 'Xcode fixture'
MOCK
chmod +x "$FIXTURE/mock-bin/"*
BUILD_ENV=(PATH="$FIXTURE/mock-bin:$PATH" FLOWSOUND_FIXTURE="$FIXTURE" APP_OUTPUT_DIR="$FIXTURE/previous.app")
expect_failure 'x86_64 Mach-O SDK does not match' run_fixture "${BUILD_ENV[@]}" FIXTURE_INTEL_SDK_VERSION=15.0 "$FIXTURE/scripts/build-app.sh" release
[[ ! -e "$FIXTURE/signing.log" && "$(cat "$FIXTURE/previous.app/keep.txt")" == 'old bundle' ]]
expect_failure 'minimum target does not match' run_fixture "${BUILD_ENV[@]}" FIXTURE_MINIMUM_VERSION=26.0 "$FIXTURE/scripts/build-app.sh" release
[[ ! -e "$FIXTURE/signing.log" && "$(cat "$FIXTURE/previous.app/keep.txt")" == 'old bundle' ]]
run_fixture "${BUILD_ENV[@]}" "$FIXTURE/scripts/build-app.sh" release > /dev/null
[[ -f "$FIXTURE/signing.log" && -f "$FIXTURE/previous.app/Contents/MacOS/FlowSound" ]]
(( ++test_count ))

# Explicit signing and notarization failures must abort, never turn into an
# ad-hoc package. These commands still use only the fixture compiler/signers.
PACKAGE_ENV=(PATH="$FIXTURE/mock-bin:$PATH" FLOWSOUND_FIXTURE="$FIXTURE")
expect_failure 'Fixture Developer ID signing failed' run_fixture "${PACKAGE_ENV[@]}" \
    SIGN_IDENTITY='Developer ID Application: Fixture' FIXTURE_FAIL_SIGNING=1 "$PACKAGE"
[[ ! -e "$FIXTURE/dist/1.2.3/test" && ! -e "$FIXTURE/dist/1.2.3/.test.lock" ]]
expect_failure 'Fixture notarization failed' run_fixture "${PACKAGE_ENV[@]}" \
    SIGN_IDENTITY='Developer ID Application: Fixture' NOTARIZE=1 NOTARYTOOL_PROFILE=fixture "$PACKAGE"
[[ ! -e "$FIXTURE/dist/1.2.3/test" && ! -e "$FIXTURE/dist/1.2.3/.test.lock" ]]
run_fixture "${PACKAGE_ENV[@]}" "$PACKAGE" > /dev/null
/usr/bin/grep -Fxq 'Signing: ad-hoc' "$FIXTURE/dist/1.2.3/test/BUILD_INFO.txt"
/usr/bin/grep -Fxq 'Notarized: 0' "$FIXTURE/dist/1.2.3/test/BUILD_INFO.txt"
/usr/bin/grep -Fq 'This release is ad-hoc signed and is not notarized.' "$FIXTURE/dist/1.2.3/test/RELEASE_NOTES.md"
(cd "$FIXTURE/dist/1.2.3/test" && shasum -a 256 -c SHA256SUMS.txt > /dev/null)
(( ++test_count ))
print -- "Release safeguards passed ($test_count checks)."
