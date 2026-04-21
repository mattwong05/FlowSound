# Contributing

## Development Setup

1. Use macOS 26 or newer.
2. Install Xcode with the macOS 26 SDK.
3. Install Xcode Command Line Tools.
4. Initialize Git before implementation work begins.
5. Open the Xcode project once it exists and confirm signing settings.

Optional tools:

- SwiftLint.
- SwiftFormat.

## Build and Test

Run unit tests:

```sh
swift test
```

Build a local app bundle:

```sh
scripts/build-app.sh
```

Build a release archive and checksum:

```sh
scripts/package-release.sh
```

Run the app:

```sh
open .build/FlowSound.app
```

Launch-at-login uses `SMAppService` and should be validated with a signed, installed app bundle before release. Local `.build/FlowSound.app` builds may report `notFound` before registration or `requiresApproval` while macOS is waiting for user approval. Saving Preferences without changing the launch-at-login checkbox must not register another login item.

## Release Process

Release builds are created with `scripts/package-release.sh`.

Default behavior:

- Builds `FlowSound.app` with SwiftPM release configuration.
- Creates `dist/FlowSound-<version>.zip`.
- Creates `dist/SHA256SUMS.txt`.

Optional signed and notarized behavior:

- Set `SIGN_IDENTITY` to a Developer ID Application identity.
- Set `NOTARIZE=1`.
- Set `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`.

Example:

```sh
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
NOTARIZE=1 \
APPLE_ID="developer@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
scripts/package-release.sh
```

An `Apple Development` certificate is for local development and is not sufficient for public Developer ID distribution. Public releases should use a paid Apple Developer Program Developer ID Application certificate.

GitHub Actions can build release artifacts from tags. Configure these repository secrets before enabling signed releases:

- `DEVELOPER_ID_CERTIFICATE_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `DEVELOPER_ID_SIGN_IDENTITY`
- `KEYCHAIN_PASSWORD`
- `NOTARIZE_RELEASE`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

## Development Rules

- Keep business logic testable outside the menu bar UI.
- Put Core Audio code behind a narrow `AudioWatcher` interface.
- Put Apple Music automation behind a narrow `MusicController` interface.
- Do not let AppleScript own state transitions.
- Keep permission errors visible in app state and logs.

## Testing Expectations

Before merging functional changes:

- Run unit tests.
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
- Save Preferences repeatedly while launch-at-login requires approval and confirm System Settings does not gain duplicate login items.
- Interrupt a restore by starting watched audio again during fade-in, then confirm Apple Music eventually returns to the original pre-duck volume.
- Confirm Apple Music does not resume when the user paused it manually.
- Confirm FlowSound skips ducking when Apple Music is paused or stopped before watched audio starts.
- Confirm disabling the service cancels active fades and timers.
- For public releases, verify the zip checksum, install from `/Applications`, confirm Gatekeeper opens the app, confirm the app is notarized, and confirm first-run permission prompts are understandable.

## Versioning

FlowSound follows Semantic Versioning:

- MAJOR for breaking changes.
- MINOR for new features.
- PATCH for bug fixes, refactors, and internal changes.

Non-trivial changes must update:

- `VERSION`
- `CHANGELOG.md`
- User-facing docs affected by the change

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
