# Agent Workflow

This file describes how coding agents should work in FlowSound.

## Project Role

Act as a senior software engineer and release manager. Prefer native macOS APIs, small interfaces, explicit state, and testable logic.

## Documentation-First Rule

After functional or behavioral changes, consider and update:

- `README.md`
- `ROADMAP.md`
- `AGENT.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `ARCHITECTURE.md`
- `VERSION`

If a document does not need a change, mention that in the final response.

## Versioning

Use Semantic Versioning:

- MAJOR for breaking changes.
- MINOR for new features.
- PATCH for bug fixes, refactors, and internal changes.

Update `VERSION` and `CHANGELOG.md` for non-trivial changes.

## Commit Planning

After validation, create Conventional Commits containing only relevant changes. Report actual commit hashes and included files; do not propose uncreated commits.

Allowed commit types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `test`
- `chore`
- `style`

## Engineering Constraints

- Keep `main` on the last stable public release. Put new features and release-candidate fixes on `dev` until they are ready for default downloads.
- Keep Core Audio code isolated from UI.
- Keep watched app whitelist parsing and validation in settings code, not Core Audio or UI code.
- Keep monitoring mode behavior explicit in settings and docs.
- Keep excluded bundle identifier behavior explicit in settings and docs.
- Keep known helper-process expansion explicit and documented.
- Keep release packaging, version metadata injection, changelog checks, signing, notarization, and checksum behavior documented.
- Keep website deployment and multilingual landing page behavior documented.
- Keep music app automation isolated behind `MusicControlAdapter` capability boundaries.
- Label adapter support levels explicitly; do not present experimental or community adapters as official support.
- Treat permission failures as explicit states.
- Avoid silent behavior changes.
- Prefer unit-testable state machine logic.
- Do not resume the selected music app unless FlowSound paused it.

## Reliability Validation

- Keep startup/status and signal observations separate; missing samples are not measured silence.
- Keep IO callbacks off the queue that destroys audio resources; send only scalar measurements across queues.
- Bind restore ownership to the player and running instance; invalidate stale async generations and honor observable user intervention.
- Keep the automation helper limited to fixed commands, never caller-supplied scripts.
- Run `swift test` and `scripts/test-release.sh`; verify universal packaging when release code changes.
- Update `docs/COMPATIBILITY.md` with distinct compiler, UI-preview, signing/permission, runtime and hardware evidence.
