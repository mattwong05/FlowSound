# Roadmap

## 0.1.x Documentation and Prototype Planning

- Document feasibility, architecture, permissions, and testing requirements.
- Create a minimal Xcode project.
- Prove Apple Music volume, pause, and play control through AppleScript.
- Prove Core Audio tap capture for one known app.

## 0.2.x MVP

- Implement menu bar enable/disable.
- Implement fixed Safari and Telegram whitelist.
- Implement duck, pause, restore, and fade-in state machine.
- Add unit tests for state transitions.
- Add local app bundle packaging.

## 0.3.x Preferences and App Icon

- Add preferences UI for timing, threshold, fade, and menu bar text visibility.
- Add generated app icon.
- Add appearance-aware About logo.

## 0.4.x Audio Detection

- Harden macOS 26 menu bar visibility with a signed Xcode app bundle and installed-app testing.
- Implement Core Audio process tap monitor behind `AudioActivityMonitor`.
- Implement RMS-based audio activity detection.
- Add tests for threshold timing and quiet-window timing.
- Add manual test checklist.

## 0.5.x Configuration

- Add editable whitelist by app bundle identifier.
- Add status and diagnostics view.

## 0.6.x Reliability

- Improve permission onboarding.
- Add recovery actions for denied permissions or failed Music automation.
- Add launch-at-login option.
- Add structured local logging.

## 1.0.0 Release Candidate

- Finalize signed and notarized distribution.
- Validate on a fresh macOS 26+ machine.
- Freeze MVP behavior and documentation.
