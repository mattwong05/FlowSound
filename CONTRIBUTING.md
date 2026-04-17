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

## Development Rules

- Keep business logic testable outside the menu bar UI.
- Put Core Audio code behind a narrow `AudioWatcher` interface.
- Put Apple Music automation behind a narrow `MusicController` interface.
- Do not let AppleScript own state transitions.
- Keep permission errors visible in app state and logs.

## Testing Expectations

Before merging functional changes:

- Run unit tests.
- Run state machine tests.
- Manually test Safari playback.
- Manually test Telegram short notification sounds and longer media playback.
- Confirm Apple Music does not resume when the user paused it manually.
- Confirm disabling the service cancels active fades and timers.

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
