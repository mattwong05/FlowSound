# Contributing

## Development Setup

1. Use macOS 15 or newer.
2. Install Xcode 26 or newer with Swift 6.2 or newer and Command Line Tools.
3. Open `Package.swift` in Xcode or use the SwiftPM commands below. No generated Xcode project is required.
4. Run `scripts/check-toolchain.sh`. CI validates the selected toolchain; repository variables `FLOWSOUND_XCODE_MAJOR` (default 26) and optional `FLOWSOUND_XCODE_VERSION` pin expectations without guessing installed paths.

Optional tools:

- SwiftLint.
- SwiftFormat.

## Build and Test

Run unit tests:

```sh
swift test
```

Preview and exercise the native interface in an interactive macOS session:

```sh
scripts/preview-ui.sh
```

This builds a separate preview app with a fake music adapter, a manual monitor and temporary preferences. It checks draft removal, empty-list Save, exact slider values, Reset and Cancel, then captures English/Chinese, light/dark, long-list and short-window cases under `.build/ui-preview/`. Screen capture must already be available to the invoking terminal. It does not start production audio monitoring or control a music player. Inspect the captures against [the interface design](docs/DESIGN.md); this is layout and interaction evidence, not installed-app or accessibility acceptance. Use the actual app separately for menu shortcuts, VoiceOver and system appearance settings.

Build a local app bundle:

```sh
scripts/build-app.sh
```

Build a release archive and checksum:

```sh
scripts/package-release.sh
```

Preview the static website:

```sh
cd site
ruby -run -e httpd . -p 8080
```

Run the app:

```sh
open .build/FlowSound.app
```

Launch-at-login uses `SMAppService` and should be validated with a signed, installed app bundle before release. Local `.build/FlowSound.app` builds may report `notFound` before registration or `requiresApproval` while macOS is waiting for user approval. Saving Preferences without changing the launch-at-login checkbox must not register another login item.

## Release Process

Use `main` for the last stable public release. New product features and release-candidate fixes should land on `dev` first. Merge or fast-forward `dev` into `main` only after the build is considered stable enough for the default download path.

Release builds are created with `scripts/package-release.sh`.

Default local/test packaging:

- `scripts/package-release.sh --check` validates options/version/changelog without creating output.
- `scripts/package-release.sh` builds a universal arm64/x86_64, ad-hoc signed test package under `dist/<VERSION>/test/`.
- `ARCHITECTURES=current scripts/build-app.sh` provides a faster local host-only build. Public stable packages require universal architecture.
- `APP_OUTPUT_DIR=/absolute/new/path/FlowSound.app scripts/build-app.sh release` builds a separate app bundle for review.
- Each package contains the zip, `SHA256SUMS.txt`, `RELEASE_NOTES.md`, and `BUILD_INFO.txt`.
- Build processes receive the selected Xcode SDK through a local `SDKROOT` value and explicit Clang sysroot arguments, including when SwiftBuild filters the environment. Before signing, each Mach-O slice must report that SDK and the macOS 15 minimum target; both are recorded in `BUILD_INFO.txt`.
- Existing package directories are rejected. Move a prior output aside explicitly before repeating a package operation. Failed builds preserve previous app/output bundles.
- Assets are checked in; artwork changes explicitly run `scripts/generate-logo-assets.swift` and `iconutil -c icns -o Assets/FlowSound.icns Assets/FlowSound.iconset`.

Stable packaging requires a clean tree, a tag matching `v$(cat VERSION)` at HEAD, and HEAD to be an ancestor of `origin/main`. Use `RELEASE_CHANNEL=stable`, `RELEASE_TAG`, a Developer ID Application `SIGN_IDENTITY`, and `NOTARIZE=1`. Both signing paths include `packaging/FlowSound.entitlements`; Developer ID signing enables Hardened Runtime. Prefer an existing Keychain notarytool profile via `NOTARYTOOL_PROFILE`; CI can use `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` supplied through secrets. Never commit or print credentials.

The Release workflow requires certificate/password/keychain/signing identity and Apple notarization secrets for tag-triggered stable releases. `NOTARIZE_RELEASE` is no longer used: stable releases always notarize. Manual workflow runs, including those selected from a tag, only produce test artifacts. Existing GitHub Releases are not overwritten. Public packages are checked with codesign, stapler, spctl, architecture validation, and checksums before publication.

CI runs on pull requests and main/dev/codex branches, executing `swift test`, a Release build, universal packaging, and `scripts/test-release.sh`. Toolchain success is not runtime compatibility evidence: signed installation, TCC permissions, real players, and hardware require [the acceptance matrix](docs/COMPATIBILITY.md).

### Public previews

When publication is authorized but Developer ID signing/notarization is unavailable, a verified `test` artifact may be published explicitly as a GitHub prerelease. Use a `preview-<VERSION>` tag on the reviewed development commit, `gh release create --verify-tag --prerelease --latest=false`, and an explicit ad-hoc/not-notarized notice in the notes and website. Upload the archive, checksum and build information together; do not replace existing assets. `preview-` tags do not trigger the stable `v*.*.*` workflow. Leave the latest stable release and `main` application code unchanged. Website-only updates may be applied to `main` so its existing Cloudflare Pages integration can publish preview information. Stable signing and acceptance gates still apply before promotion.

## Website Deployment

The landing page is a no-build static site in `site/`.

Cloudflare Pages settings:

- Framework preset: `None`
- Build command: leave empty
- Build output directory: `site`
- Production branch: `main`
- Recommended custom domain: `flowsound.youseminar.cn`

Keep the landing page copy straightforward. The page should explain what FlowSound does, show the demo video, link to GitHub and downloads, and describe permissions clearly.

## Development Rules

- Keep business logic testable outside the menu bar UI.
- Put Core Audio code behind a narrow `AudioWatcher` interface.
- Put music app automation behind a narrow `MusicControlAdapter` interface.
- Declare adapter capabilities and support level before wiring a player into product flows.
- Keep experimental or community adapters out of the official support path until their playback-state, volume-control, permission, and restore behavior are validated.
- Do not let AppleScript own state transitions.
- Keep permission errors visible in app state and logs.

## Testing Expectations

Before merging functional changes:

- Run unit tests.
- For interface changes, run the native preview above and inspect all affected panes, empty states, long names and expanded advanced sections. Keep toolbar controls and Save/Cancel reachable on short screens, and test keyboard focus through the application lists.
- Prefer polling expected async service state in tests instead of relying on fixed sleeps.
- For launch-at-login changes, test both paths: changing the checkbox should call the native registration path, while saving Preferences again without changing the checkbox should leave the login item untouched.
- Run state machine tests.
- Manually test Safari playback in all-apps monitoring mode.
- Confirm Safari playback logs either RMS activity or a matched WebKit output process.
- Manually test Telegram short notification sounds and longer media playback in all-apps monitoring mode.
- Manually test a short macOS notification sound and confirm it does not trigger ducking.
- Manually test excluded bundle identifiers by adding a noisy app and confirming it is ignored in all-apps mode.
- Manually test watched-app-only mode after changing the monitoring mode in Preferences.
- Manually test a custom watched bundle identifier from Preferences, then reset defaults.
- Play audio in a few apps and confirm Preferences > Tools lists recent audio sources with bundle identifiers and statuses.
- Change the Preferences language selection and confirm the Preferences and menu titles rebuild in the selected language.
- Save Preferences repeatedly while launch-at-login requires approval and confirm System Settings does not gain duplicate login items.
- Change raw rules, use a recent-source action or app picker, then Cancel; confirm persisted rules remain unchanged. Repeat with Save and verify exclusion precedence.
- Confirm language/fade-only edits do not restart the tap.
- Exercise delayed duck completion, disabled player changes, stale callbacks, missing samples, and monitor recovery with test doubles before hardware tests.
- Interrupt a restore by starting watched audio again during fade-in, then confirm the selected music app eventually returns to the original pre-duck volume.
- Confirm the selected music app does not resume when the user paused it manually.
- Confirm FlowSound skips ducking when the selected music app is paused or stopped before watched audio starts.
- Manually test Apple Music and Spotify as the selected music app.
- Confirm disabling the service cancels active fades and timers.
- For public releases, verify the zip checksum, install from `/Applications`, confirm Gatekeeper opens the app, confirm the app is notarized, and confirm first-run permission prompts are understandable.
- For unsigned tester releases, unzip the archive and run `codesign --verify --deep --strict --verbose=2 FlowSound.app` before publishing.
- For website changes, test light mode, dark mode, English, Simplified Chinese, desktop width, and mobile width before deployment.

## Versioning

FlowSound follows Semantic Versioning:

- MAJOR for breaking changes.
- MINOR for new features.
- PATCH for bug fixes, refactors, and internal changes.

Non-trivial changes must update:

- `VERSION`
- `CHANGELOG.md`
- User-facing docs affected by the change

Before publishing a GitHub Release, run the stable packaging command described above from a clean tree and inspect `dist/<VERSION>/stable/RELEASE_NOTES.md`. Do not publish or replace release assets if the app bundle metadata, archive name, changelog section, and release notes do not all refer to the same version.

## Commit Style

Use Conventional Commits:

```text
feat(scope): short summary
fix(scope): short summary
docs(scope): short summary
refactor(scope): short summary
test(scope): short summary
chore(scope): short summary
style(scope): short summary
```
