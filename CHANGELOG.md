# Changelog

All notable changes to FlowSound will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

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
