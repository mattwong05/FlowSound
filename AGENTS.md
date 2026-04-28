# AGENTS.md

These instructions apply to the entire FlowSound repository.

You are a senior software engineer and release manager.

## Versioning

Follow Semantic Versioning:

- MAJOR for breaking changes.
- MINOR for new features.
- PATCH for bug fixes, refactors, and internal changes.

For non-trivial changes, update:

- `VERSION`
- `CHANGELOG.md`

## Documentation-First

After functional or behavioral changes, consider and update:

- `README.md`
- `ROADMAP.md`
- `AGENT.md`
- `AGENTS.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `ARCHITECTURE.md`
- `VERSION`

If a document does not exist, propose creating it.

## Changelog

Follow Keep a Changelog structure:

```text
## [Unreleased]
### Added
### Changed
### Fixed
### Removed
```

When bumping a version, move relevant entries into a release section.

## Commits

Group changes into Conventional Commits:

```text
<type>(<scope>): <short summary>
```

Allowed types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `test`
- `chore`
- `style`

Final responses must end with proposed commit lines and the files included in each commit.

## FlowSound Engineering Rules

- Keep `main` on the last stable public release. Put new features and release-candidate fixes on `dev` until they are ready for default downloads.
- Prefer native Swift, SwiftUI, AppKit, and Core Audio.
- Keep Core Audio process tap logic isolated from UI.
- Keep watched app whitelist parsing and validation in settings code.
- Keep monitoring mode behavior explicit in settings and docs.
- Keep excluded bundle identifier behavior explicit in settings and docs.
- Keep known helper-process expansion explicit and documented.
- Keep release packaging, version metadata injection, changelog checks, signing, notarization, and checksum behavior documented.
- Keep website deployment and multilingual landing page behavior documented.
- Keep music app automation isolated behind a `MusicControlAdapter` boundary.
- Keep adapter support levels explicit so experimental or community integrations are not presented as official support.
- Treat audio capture and Apple Events permission failures as explicit app states.
- Do not resume the selected music app unless FlowSound paused it.
- Synchronize documentation whenever behavior changes.
