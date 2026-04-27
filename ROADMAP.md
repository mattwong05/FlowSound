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

## 0.4.x Activation State Icons

- Start FlowSound activated by default on launch.
- Add active and deactivated menu bar icon states.
- Generate deactivated assets from `FlowSound-Deactivate-iCon.png`.

## 0.5.x Audio Detection

- Implement Core Audio process tap monitor behind `AudioActivityMonitor`.
- Implement RMS-based audio activity detection.
- Add tests for threshold timing and quiet-window timing.
- Add manual test checklist.

## 0.6.x Login and Preferences Polish

- Add launch-at-login control through `SMAppService`.
- Add Preferences checkbox for launch-at-login.
- Fix Preferences form spacing.

## 0.7.x Configuration

- Add editable whitelist by app bundle identifier.
- Persist and validate watched app bundle identifiers.
- Add status and diagnostics view.

## 0.8.x Reliability

- Expand Safari watching to include WebKit audio helper processes.
- Add process-output fallback diagnostics for watched apps.

## 0.9.x Monitoring Modes

- Add all-apps-except-Apple-Music monitoring mode.
- Keep watched-app-only mode for stricter filtering.
- Tune default timing values for smoother duck and restore behavior.
- Reduce fallback detector active/quiet thrashing.

## 0.10.x Notification Filtering

- Add excluded bundle identifiers for all-apps monitoring mode.
- Add default exclusions for common system notification services.
- Keep process-output fallback diagnostic-only in all-apps mode.
- Stabilize launch-at-login registration behavior for local app builds.
- Preserve Apple Music restore volume across interrupted duck/restore cycles.

## 0.11.x Reliability

- Harden macOS 26 menu bar visibility with a signed Xcode app bundle and installed-app testing.
- Improve permission onboarding.
- Add recovery actions for denied permissions or failed Music automation.
- Validate launch-at-login behavior in a signed and installed app.
- Add structured local logging.
- Add public release packaging, checksums, privacy documentation, and GitHub Actions release workflow.

## 0.12.x Website

- Add a simple public landing page.
- Embed the demo video.
- Explain permissions in plain language.
- Support English and Simplified Chinese.
- Deploy with Cloudflare Pages.

## 0.13.x Music Apps and Compatibility

- Lower the supported runtime target to macOS 15+ with a process-object-ID tap fallback for macOS 15-25.
- Add Spotify as a selectable music app controlled through AppleScript.
- Add English and Simplified Chinese app UI based on system language, defaulting to English.
- Redesign Preferences with clearer sections and advanced bundle identifier filters collapsed by default.

## 0.14.x Preferences and Diagnostics

- Add app language selection with System, English, and Simplified Chinese options.
- Move Preferences into General, Monitoring, and Tools tabs.
- Keep the menu bar item icon-only.
- Add recently detected audio sources to help users discover bundle identifiers for watched and excluded app rules.

## 0.15.x Adapter Architecture

- Add a `MusicControlAdapter` capability model for official, experimental, and community player integrations.
- Keep Apple Music and Spotify on the official absolute-volume adapter path.
- Add Netease Cloud Music as an experimental relative-step adapter using menu-state playback detection and Core Audio output feedback.
- Add adapter profile import/export for transparent community adapter metadata.
- Defer Adapter Lab UI until the adapter capability model and profile format are stable.

## 1.0.0 Release Candidate

- Finalize signed and notarized distribution.
- Validate on fresh macOS 15+ and macOS 26+ machines.
- Freeze MVP behavior and documentation.
