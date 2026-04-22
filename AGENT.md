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

End work with proposed Conventional Commits, including file lists.

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
- Keep release packaging, signing, notarization, and checksum behavior documented.
- Keep website deployment and multilingual landing page behavior documented.
- Keep music app automation isolated from product state.
- Treat permission failures as explicit states.
- Avoid silent behavior changes.
- Prefer unit-testable state machine logic.
- Do not resume the selected music app unless FlowSound paused it.
