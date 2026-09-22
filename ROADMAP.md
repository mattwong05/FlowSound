# Roadmap

Historical version sections below describe delivered milestones, not verification evidence. Current remaining acceptance work is tracked in [COMPATIBILITY.md](docs/COMPATIBILITY.md).

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
- Keep adapter profile import/export metadata-only until there is a reviewed sandbox model for user-authored control scripts.
- Keep release bundle metadata, changelog sections, and generated release notes synchronized from the repository version marker.
- Defer Adapter Lab UI until the adapter capability model, profile format, permission model, and debug workflow are stable.

## 0.16.x Preferences Workflow

- Add direct actions from Recently Detected Audio Sources to Watched apps and Excluded apps.
- Keep Monitoring as the editable source of truth while making common bundle identifier updates available from Tools.

## 0.17.x Reliability and Maintenance

- Implemented: session-scoped restore ownership, asynchronous monitor readiness, quiet/deferred-duck handling, bounded script execution, and observable user-intervention handling.
- Implemented: draft-only app rules, app selection, live diagnostics, bounded logs, audio recovery listeners, CI and protected universal packaging.
- Verified locally: pure/service/command/lifecycle tests and toolchain builds; see the compatibility matrix for exact evidence.
- Pending: distributed-app installation, manual first-launch approval and permission attribution, real-player fades, device switching, sleep/wake, and macOS 15/27 runtime acceptance.

## 1.0.0 Release Candidate

- Complete the ad-hoc installation, manual approval, permission and hardware matrix. Validate Developer ID signing and notarization separately if that optional distribution method is introduced.
- Validate permission denial/recovery in a fresh macOS account.
- Measure CPU, energy impact, and actual fade latency during a representative long session.
- Keep Netease experimental until its menu and approximate volume behavior pass the dedicated matrix.
- Freeze user-visible behavior and tested platform claims.

## 0.18.x Native Interface

Implemented: native settings toolbar; separate watched/ignored columns; aligned add/remove controls and empty states; dedicated sound controls; compact menu, Diagnostics and About; English/Chinese and light/dark visual review.

Distribution: 0.18.0 is the official default release, using ad-hoc signing and manual first-launch approval. The website and GitHub share the same download entry.

Next acceptance: the installed distributed UI on macOS 26 and 27, VoiceOver, increased contrast/reduced transparency, full keyboard access, and the runtime matrix in `docs/COMPATIBILITY.md`.
