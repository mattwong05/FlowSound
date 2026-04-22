# Changelog

All notable changes to FlowSound will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.14.0] - 2026-04-22

### Added

- Added Preferences language selection with System, English, and Simplified Chinese options.
- Added a tabbed Preferences layout with General, Monitoring, and Tools tabs.
- Added a Tools panel for recently detected audio sources from the last 3 minutes, including bundle identifier, pid, and current watched/excluded status.
- Added unit tests for language preference persistence and recent audio source retention.

### Changed

- Changed the menu bar item to icon-only and removed the user-facing menu bar text option.
- Moved diagnostics actions from the menu bar menu into Preferences > Tools.
- Kept watched and excluded app configuration as raw bundle identifier text editors, with Tools as the assisted discovery path.

## [0.13.1] - 2026-04-22

### Fixed

- Fixed Preferences Advanced expansion overflowing the screen and hiding the Save / Reset buttons.
- Fixed Preferences not returning to a compact height after Advanced is collapsed.

### Changed

- Clarified that new feature work should happen on the `dev` branch while `main` stays on the last stable public release.

## [0.13.0] - 2026-04-22

### Added

- Added Spotify as a selectable music app controlled through local AppleScript.
- Added English and Simplified Chinese app UI selected from the system language, defaulting to English.
- Added a clearer Preferences layout with music app selection and advanced bundle identifier filters collapsed by default.

### Changed

- Lowered the supported runtime target from macOS 26+ to macOS 15+.
- Changed Core Audio tap setup to use bundle identifiers on macOS 26+ and process object IDs on macOS 15-25.
- Updated the website, install notes, privacy notes, security notes, architecture, and roadmap for macOS 15+ and Apple Music / Spotify support.

## [0.12.2] - 2026-04-22

### Changed

- Redesigned the website hero to use a more visual before-and-after audio focus diagram.
- Moved the Product Hunt badge out of the hero visualization and into the main call-to-action area.
- Reduced the website header height and logo footprint.

## [0.12.1] - 2026-04-22

### Changed

- Changed the website hero side panel to explain the Apple Music audio-focus workflow and user pain point more directly.
- Added Product Hunt featured badge support with light and dark theme variants.

## [0.12.0] - 2026-04-22

### Added

- Added a static one-page FlowSound landing page for Cloudflare Pages.
- Added English and Simplified Chinese website copy with browser-language detection and manual language switching.
- Added YouTube demo embed, download link, GitHub link, privacy notes, permission explanations, and FAQ sections.
- Added Cloudflare Pages headers and deployment notes for the static website.

## [0.11.2] - 2026-04-21

### Fixed

- Fixed release archives containing an invalid app bundle signature by ad-hoc signing `FlowSound.app` after packaging.
- Fixed generated GitHub Release notes keeping the literal `VERSION` placeholder.

## [0.11.1] - 2026-04-21

### Fixed

- Fixed the interrupted-restore service test using fixed sleeps that could fail on slower CI runners.

## [0.11.0] - 2026-04-21

### Added

- Added public install, privacy, and security documentation for open-source distribution.
- Added release notes template for GitHub Releases.
- Added release packaging script that builds a zip archive and SHA-256 checksum file, with optional Developer ID signing and notarization.
- Added GitHub Actions release workflow for tagged builds and release artifact uploads.

## [0.10.3] - 2026-04-21

### Fixed

- Fixed interrupted restore flows overwriting the saved Apple Music restore volume with an in-progress fade volume such as `0`.

## [0.10.2] - 2026-04-18

### Fixed

- Fixed launch-at-login registration being blocked when local app builds report `SMAppService` status as `notFound`.
- Fixed Preferences Save touching the login item when the launch-at-login checkbox state did not change.

## [0.10.1] - 2026-04-18

### Fixed

- Fixed active detection being reset by brief low-RMS buffers before active duration could complete.
- Fixed repeated Preferences saves registering duplicate launch-at-login entries while approval was pending.

## [0.10.0] - 2026-04-18

### Added

- Added excluded app bundle identifiers for all-apps monitoring mode.
- Added default exclusions for Apple Music, FlowSound, and common macOS notification services.
- Added Preferences editor for excluded bundle identifiers.

### Changed

- Changed all-apps mode to use RMS tap activity as the active/quiet source while keeping process-output polling as diagnostics.
- Changed settings initialization to migrate old default timing values to the current defaults.

## [0.9.0] - 2026-04-18

### Added

- Added audio monitoring mode setting with `All apps except Apple Music` and `Only watched apps` options.
- Added default all-apps monitoring that excludes Apple Music and FlowSound.
- Added Preferences control for switching monitoring modes.
- Added tests for monitoring mode defaults, persistence, and Apple Music exclusions.

### Changed

- Changed default timings to active duration 1 second, quiet duration 3 seconds, fade-out 2 seconds, and fade-in 2 seconds.
- Changed the Core Audio process tap to use an exclusive tap in all-apps monitoring mode.
- Changed the process-output quiet release window to reduce active/quiet thrashing from the fallback detector.

## [0.8.0] - 2026-04-18

### Added

- Added automatic Safari watched-app expansion to include WebKit audio helper bundle identifiers.
- Added Core Audio process-output polling as a fallback activity signal for watched apps.
- Added diagnostic logs for active candidates, audible samples, matched output processes, audio activity changes, service events, and state transitions.
- Added Apple Music playback-state check before ducking.
- Added tests for Safari helper bundle expansion.

### Changed

- Changed Core Audio startup logs to include the expanded watched bundle identifiers.
- Changed ducking behavior so FlowSound skips pause/restore when Apple Music is not already playing.

## [0.7.0] - 2026-04-18

### Added

- Added editable watched app bundle identifiers in Preferences.
- Added bundle identifier parsing, validation, deduplication, and persistence.
- Added settings tests for watched app whitelist parsing and storage.

### Changed

- Changed Core Audio process tap setup to use the persisted watched app whitelist.

## [0.6.0] - 2026-04-18

### Added

- Added launch-at-login control using `SMAppService.mainApp`.
- Added Preferences checkbox and status text for launch-at-login.
- Added shortcut from Preferences to System Settings Login Items.

### Changed

- Reworked Preferences form layout to use fixed-height rows and avoid large spacing between fade settings.

## [0.5.0] - 2026-04-18

### Added

- Added `CoreAudioProcessTapMonitor` using Core Audio process taps.
- Added bundle ID-based audio capture for the fixed Safari and Telegram whitelist.
- Added RMS-based activity detection with active duration and quiet release timing.
- Added private aggregate device and IO proc setup for reading tap buffers.

### Changed

- Changed default audio monitoring from manual simulation to Core Audio process tap monitoring.
- Moved Core Audio tap setup off the main AppKit thread.

## [0.4.0] - 2026-04-18

### Added

- Added deactivated icon asset generation from `FlowSound-Deactivate-iCon.png`.
- Added active and inactive menu bar template icons.
- Added default service activation on app launch.

### Changed

- Changed menu bar toggle wording to Activate / Deactivate.
- Changed menu bar icon rendering to follow the current activation state.
- Changed state labels from listening / disabled to activated / deactivated for user-facing status.

## [0.3.0] - 2026-04-17

### Added

- Added Preferences window for threshold, timing, fade, and menu bar text settings.
- Added persistent settings storage through `UserDefaults`.
- Added generated `.icns` app icon and bundle icon declaration.
- Added appearance-aware About logo selection for light and dark mode.

### Changed

- Changed startup diagnostics window to a manual menu action instead of showing on every launch.
- Changed menu bar presentation to respect the user's text visibility preference.
- Changed app packaging to generate iconset and `.icns` assets.

## [0.2.2] - 2026-04-17

### Added

- Added explicit AppKit main entry point for the menu bar app.
- Added local diagnostics logging at `~/Library/Logs/FlowSound/FlowSound.log`.
- Added startup diagnostics window for development builds.
- Added diagnostics path menu item.

### Changed

- Changed the status item to a fixed-width visible text-and-icon menu item.

### Fixed

- Improved diagnosis for cases where macOS launches FlowSound but the menu bar item is not visible.

## [0.2.1] - 2026-04-17

### Added

- Added generated logo assets split from the supplied source artwork.
- Added visible menu bar icon fallback using a generated template image and text fallback.

### Changed

- Changed the About window to use the split light-background logo asset.
- Changed app bundle builds to regenerate logo assets automatically.

### Fixed

- Fixed invisible menu bar status item when the previous SF Symbol name was unavailable.

## [0.2.0] - 2026-04-17

### Added

- Added native Swift Package executable for the FlowSound menu bar app.
- Added AppKit status menu with enable, disable, quit, and manual audio simulation controls.
- Added ducking state machine for listening, ducking, paused, restoring, disabled, and error states.
- Added Apple Music controller using AppleScript through `osascript`.
- Added fade-out, pause, resume, and fade-in service orchestration.
- Added About window that displays the supplied FlowSound logo artwork.
- Added app bundle packaging script and Info.plist permission descriptions.
- Added state machine tests.
- Added project ignore rules for SwiftPM and Xcode build output.

## [0.1.0] - 2026-04-17

### Added

- Initialized product documentation for FlowSound.
- Added technical feasibility assessment for macOS 26+ background music ducking.
- Documented required development, runtime, permission, and testing environment.
- Added initial architecture, roadmap, contribution process, and agent workflow notes.
- Added repository-level `AGENTS.md` instructions for future agent work.
