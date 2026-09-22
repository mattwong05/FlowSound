# Changelog

All notable changes to FlowSound will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.18.0] - 2026-09-23

### Added

- Added separate application-rule columns with fixed headers, application counts, empty states, friendly system names, and aligned keyboard-accessible removal controls.
- Added a dedicated Sound pane with native sliders and exact numeric inputs for fade, restore and detection timing.
- Added a documented native macOS design baseline and repeatable visual acceptance guidance.
- Added an isolated native preview script for screenshot review and settings draft, persistence and keyboard-focus checks.

### Changed

- Replaced in-content segmented navigation with a native settings toolbar for General, Applications, Sound and Tools, with pane-sized windows and a fixed Save/Cancel footer.
- Separated always-ignored music players and FlowSound from editable rule rows; advanced identifiers and community adapters are disclosed on demand.
- Redesigned Diagnostics with aligned information rows, contextual settings actions and collapsible technical tools, and made About compact.
- Simplified the native menu bar menu and added the standard Settings keyboard shortcut in the application menu.
- Updated English and Simplified Chinese copy, semantic light/dark colors, spacing, and control hierarchy while preserving draft Save/Cancel behavior.

### Fixed

- Fixed application removal buttons moving with app-name length and list headings appearing inside the shared scrolling content.
- Fixed outer scrolling content overlapping list actions, and disclosure controls hiding their labels.
- Kept keyboard focus in the edited rule column when the same identifier appears in both lists.

## [0.17.0] - 2026-09-23

### Added

- Added live diagnostics for monitoring, player automation, Accessibility, login items, and restore countdowns, with retry and permission settings shortcuts.
- Added native application selection with app names/icons and draft-only watched/excluded rules; kept raw identifiers as an advanced editor.
- Added bounded audio-monitor recovery for output device/format changes, sleep/wake, and legacy process-list changes.
- Added regression tests for asynchronous control, signal timing, PCM formats, process cancellation, settings drafts, and release safeguards.
- Added PR/development CI, universal arm64/x86_64 packaging, build provenance, and a macOS compatibility acceptance matrix.

### Changed

- Changed monitoring startup to report actual readiness and errors, with session-scoped callbacks and fresh signal observations after restart.
- Changed all Preferences changes, including recent-source actions, app removal and Reset, to require Save; Cancel discards drafts. Explicitly empty app lists now remain empty after saving instead of returning to defaults.
- Changed official-player fades to one bounded script process per fade. Netease UI scripts run on the main thread of a short-lived copy of the signed app executable, keeping the menu app responsive.
- Changed restore ownership to track the selected player and running instance, rejecting stale results and observable manual playback/volume changes.
- Changed logs to serialized asynchronous writes with one 1 MiB current file and one rotated file.
- Changed public releases to require Developer ID signing, the Apple Events entitlement, notarization, matching version/tag metadata, and stable-branch ancestry. Manual workflow runs only create test artifacts.
- Changed artifact output to `dist/<version>/<test|stable>/`; existing output and public release assets are never silently replaced.

### Fixed

- Fixed music remaining paused when the quiet deadline expires during the initial fade-out.
- Fixed old restore volumes crossing into a different player selected while FlowSound is disabled.
- Fixed initialization errors being hidden behind an activated status and quiet synchronization being lost when monitoring rules change.
- Fixed PCM format flag interpretation, partial probe initialization cleanup, and stale/missing samples being counted as confirmed silence.
- Fixed unrelated language/fade settings restarting the audio tap and login-item errors being overwritten by a form refresh.
- Fixed packaging SDK metadata by explicitly passing the selected SDK to build processes and verifying both Mach-O slices, while keeping the macOS 15 deployment target.

## [0.16.0] - 2026-04-28

### Added

- Added quick actions in Preferences > Tools for adding recently detected audio source bundle identifiers directly to Watched apps or Excluded apps.
- Added default handling for the `systemsoundserverd` Core Audio system process so macOS system sound output can be excluded from FlowSound monitoring.

### Changed

- Changed watched-app monitoring so Excluded apps override Safari helper expansion such as WebKit audio processes.
- Changed Monitoring bundle identifier editors to support standard paste and undo shortcuts.

## [0.15.1] - 2026-04-28

### Fixed

- Fixed release app bundle metadata so `CFBundleShortVersionString`, `CFBundleVersion`, and the About window version are generated from `VERSION`.
- Fixed release packaging to fail when the built app bundle version does not match `VERSION`.
- Fixed release packaging to fail when `CHANGELOG.md` does not contain a matching release section instead of publishing placeholder release notes.
- Fixed Netease Cloud Music playback-state detection for Chinese and English Controls menu titles.

## [0.15.0] - 2026-04-28

### Added

- Added a `MusicControlAdapter` capability model for official, experimental, and community music app integrations.
- Added adapter metadata for support level, bundle identifiers, playback-state capability, and volume-control capability.
- Added Netease Cloud Music as an experimental adapter using menu-state playback detection, relative volume steps, and Core Audio output feedback.
- Added adapter profile import/export for transparent community adapter metadata.
- Added tests that verify Apple Music and Spotify remain official absolute-volume adapters.
- Added tests for the Netease experimental adapter descriptor and adapter profile import/export.

### Changed

- Migrated the existing AppleScript music control path to `AppleScriptMusicControlAdapter` while preserving current Apple Music and Spotify behavior.
- Changed the Preferences music app picker to show experimental support levels instead of presenting all adapters as official support.
- Changed Netease Cloud Music restore to use a more conservative relative-step count to avoid increasing volume after each duck/restore cycle.
- Changed Netease adapter profile export to write a local JSON file under Application Support and reveal it in Finder instead of using a save panel.
- Changed adapter profile import to read local JSON files from FlowSound's Application Support profile folder instead of opening a panel.
- Changed Netease menu automation to run inside FlowSound instead of `/usr/bin/osascript`, so Accessibility permission belongs to FlowSound.
- Tightened Preferences tab layout so fixed-height scroll areas no longer stretch section spacing.
- Tightened Preferences content heights again and removed the duplicated launch-at-login status text.
- Updated architecture and contributor documentation to keep future community adapters separate from official native support.
- Updated app and documentation copy to explain Netease Accessibility permission, approximate volume restore, and local-only adapter profiles.

## [0.14.4] - 2026-04-22

### Changed

- Updated public documentation and website copy for the current support matrix: macOS 15+, Apple Music, Spotify, and English / Simplified Chinese.
- Clarified that additional music apps can be adapted when they expose reliable local playback and volume control.

## [0.14.3] - 2026-04-22

### Fixed

- Fixed Preferences language switching leaving stale translated content layered in the window.
- Fixed repeated Preferences rebuilds accumulating reused AppKit subviews and duplicate fixed-width constraints.

## [0.14.2] - 2026-04-22

### Fixed

- Fixed Preferences opening with severe layout lag, missing content, and unresponsive tab/save controls.
- Replaced recursive Preferences height fitting with stable per-tab height targets.
- Fixed recent audio source rendering by using explicit scroll document sizing instead of fragile nested scroll constraints.

## [0.14.1] - 2026-04-22

### Fixed

- Fixed Preferences tab spacing and removed the oversized empty top gap inside tab content.
- Fixed Preferences window height so it adapts to the selected tab instead of using the tallest tab's height.
- Fixed the recently detected audio sources list so app names, bundle identifiers, pids, and watched/excluded status are visible.

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
