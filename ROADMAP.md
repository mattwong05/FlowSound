# Roadmap

## 0.1.x Documentation and Prototype Planning

- Document feasibility, architecture, permissions, and testing requirements.
- Create a minimal Xcode project.
- Prove Apple Music volume, pause, and play control through AppleScript.
- Prove Core Audio tap capture for one known app.

## 0.2.x MVP

- Implement menu bar enable/disable.
- Implement fixed Safari and Telegram whitelist.
- Implement RMS-based audio activity detection.
- Implement duck, pause, restore, and fade-in state machine.
- Add unit tests for timing and state transitions.
- Add manual test checklist.

## 0.3.x Configuration

- Add settings UI.
- Add editable whitelist by app bundle identifier.
- Add threshold, active duration, quiet duration, and fade duration controls.
- Add status and diagnostics view.

## 0.4.x Reliability

- Improve permission onboarding.
- Add recovery actions for denied permissions or failed Music automation.
- Add launch-at-login option.
- Add structured local logging.

## 1.0.0 Release Candidate

- Finalize signed and notarized distribution.
- Validate on a fresh macOS 26+ machine.
- Freeze MVP behavior and documentation.
