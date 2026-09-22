#!/bin/zsh
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { print -u2 'FlowSound builds require macOS.'; exit 1; }

# Use the selected Xcode. CI can enforce an exact version without guessing an
# /Applications path; changing the selected toolchain is an operator decision.
XCODE_VERSION="$(xcodebuild -version | awk '/^Xcode / { print $2 }')"
SWIFT_VERSION="$(swift --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -n 1)"
[[ -n "$XCODE_VERSION" && -n "$SWIFT_VERSION" ]] || { print -u2 'Unable to identify the selected Xcode and Swift toolchain.'; exit 1; }
[[ "${XCODE_VERSION%%.*}" -ge 26 ]] || { print -u2 'Xcode 26 or newer is required.'; exit 1; }
[[ "${SWIFT_VERSION%%.*}" -gt 6 || ( "${SWIFT_VERSION%%.*}" == 6 && "${SWIFT_VERSION#*.}" -ge 2 ) ]] || {
    print -u2 'Swift 6.2 or newer is required.'; exit 1
}
if [[ -n "${EXPECTED_XCODE_MAJOR:-}" && "${XCODE_VERSION%%.*}" != "$EXPECTED_XCODE_MAJOR" ]]; then
    print -u2 'Selected Xcode major does not match EXPECTED_XCODE_MAJOR.'; exit 1
fi
if [[ -n "${EXPECTED_XCODE_VERSION:-}" && "$XCODE_VERSION" != "$EXPECTED_XCODE_VERSION" ]]; then
    print -u2 'Selected Xcode version does not match EXPECTED_XCODE_VERSION.'; exit 1
fi
print -- "Selected Xcode $XCODE_VERSION; Swift $SWIFT_VERSION; macOS SDK $(xcrun --sdk macosx --show-sdk-version)."
