# FlowSound

FlowSound is a macOS menu bar app that keeps Apple Music or Spotify playing as background music, then automatically fades and pauses it when other apps start playing audio. When those apps become quiet again, FlowSound resumes the selected music app and fades it back to the previous volume. Netease Cloud Music is available as an experimental adapter.

The target platform is macOS 15+. FlowSound uses Core Audio process taps for outgoing process audio detection. On macOS 26 and newer it can configure taps by bundle identifier; on macOS 15-25 it falls back to process object IDs available when the tap starts.

## Website

The FlowSound landing page is designed for Cloudflare Pages:

```text
flowsound.youseminar.cn
```

The static site lives in [`site/`](site/) and supports English and Simplified Chinese. It defaults to English unless the browser language starts with `zh`; users can switch languages manually. The hero explains the audio-focus workflow with a before-and-after diagram and includes a Product Hunt badge with light and dark variants near the main download action.

## Download

Public releases are published on GitHub:

https://github.com/mattwong05/FlowSound/releases

Download `FlowSound-<version>.zip` and `SHA256SUMS.txt`, then verify the archive:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

See [INSTALL.md](INSTALL.md) for installation, first-run permissions, unsigned build notes, and uninstall steps.

## Branch Policy

The `main` branch tracks the last stable public release. New features and release-candidate fixes are developed on `dev` first, then promoted to `main` only after they are ready for the default download path.

## Trust and Privacy

FlowSound is open source and designed to be local-first:

- No network feature.
- No analytics.
- No ads.
- No audio uploads.
- No saved captured audio.

FlowSound detects whether other apps are producing audio, then controls the selected music app locally through Apple Events or explicit adapter commands. See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md) for details.

Apple Music and Spotify are official supported music apps. Netease Cloud Music is experimental: it uses menu-state playback detection, relative volume steps, Accessibility permission, and Core Audio output feedback to confirm fade-out silence. Netease playback-state detection recognizes both English and Simplified Chinese Controls menu titles.

Netease Cloud Music requires Accessibility permission because FlowSound must click the app's Controls menu through local macOS UI scripting. Its volume restore is approximate: Netease exposes relative volume menu steps, usually about 5%, and does not expose an exact readable volume through AppleScript.

If Netease control still reports `osascript is not allowed assistive access` or `-1719` after enabling Accessibility, remove FlowSound from the Accessibility list and add the current rebuilt app again. macOS can treat a rebuilt ad-hoc signed app as a different automation client.

## Current Implementation

The current build is a native Swift menu bar app with:

- One-click enable and disable from the menu bar.
- A tested ducking state machine.
- Apple Music and Spotify control through AppleScript and `osascript`.
- A `MusicControlAdapter` capability model that separates official absolute-volume players from future experimental or community relative-step adapters.
- Experimental Netease Cloud Music support through menu commands and relative-step fade control.
- Adapter profile import/export for transparent community adapter metadata. Profiles are local JSON descriptions, not executable plugins, and do not trigger network requests or arbitrary script downloads.
- Fade-out, pause, play, and fade-in behavior.
- Playback-state check so FlowSound only restores music that it paused itself.
- Core Audio process tap monitoring for all non-selected-music-app audio by default.
- Optional watched-app-only monitoring through bundle ID-based taps.
- Automatic Safari expansion to include WebKit audio helper processes used by sites such as YouTube.
- Process-output polling fallback for watched apps when the tap has not produced an RMS activity signal yet.
- Manual menu items to simulate watched audio and quiet periods for debugging.
- Split logo assets generated from `FlowSound-iCon.png`, including dark-background, light-background, and menu bar template variants.
- An About window that chooses the light or dark FlowSound logo artwork based on appearance.
- A localized English and Simplified Chinese interface selected from system language, defaulting to English.
- A tabbed Preferences window for General, Monitoring, and Tools settings.
- Language selection with System, English, and Simplified Chinese options.
- A Tools panel that lists recently detected audio sources from the last 3 minutes with bundle identifier, pid, and watched/excluded status.
- A generated `.icns` app icon bundled into `FlowSound.app`.
- Default activation on launch, with manual Activate / Deactivate control from the menu bar.
- Active and deactivated menu bar icons generated from the supplied icon artwork.
- App bundle packaging with Apple Events and system audio capture usage descriptions.

The default monitoring mode listens to all app audio except the selected music app, FlowSound, and common macOS notification services. You can edit exclusions or switch to watched-app-only mode in Preferences.

## MVP Behavior

- Watch all apps except the selected music app by default, or a configurable whitelist in watched-app-only mode.
- Treat app audio as active only after it produces audio above a threshold for 1 second.
- Fade the selected music app volume down over 2 seconds.
- Pause the selected music app after the fade-out completes.
- Resume the selected music app after 3 seconds of quiet.
- Fade the selected music app volume back to the volume captured before ducking.
- Preserve the captured restore volume if restoring is interrupted by new app audio.
- Skip ducking and restoring when the selected music app is not already playing.
- Provide a one-click menu bar toggle to enable or disable the service.
- Start activated when the app launches.

## Technical Approach

FlowSound is implemented as a native Swift app:

- App shell: AppKit menu bar integration.
- Audio detection: Core Audio process taps through the `AudioActivityMonitor` boundary.
- Signal analysis: short-window RMS or peak detection.
- Music app control: `MusicControlAdapter` implementations. Current official adapters use AppleScript for Apple Music and Spotify with native playback-state and absolute-volume control.
- Coordination: explicit state machine to avoid repeated pause/resume loops.
- Configuration: local settings for selected music app, language, monitoring mode, whitelist, exclusions, thresholds, fade durations, and enablement.

See [ARCHITECTURE.md](ARCHITECTURE.md) and [docs/TECHNICAL_FEASIBILITY.md](docs/TECHNICAL_FEASIBILITY.md) for details.

## Required Environment

For development:

- macOS 15 or newer for the product target.
- Xcode with a recent macOS SDK. Current release builds are produced with Xcode 26.
- Xcode Command Line Tools.
- Swift and Swift Package Manager as provided by Xcode.
- Git, recommended before implementation starts.
- Apple Developer account, recommended for Developer ID signing, notarization, and testing permission flows close to release behavior.

No third-party runtime dependency is required for the planned MVP.

Optional developer tools:

- SwiftLint for style checks.
- SwiftFormat for consistent formatting.
- Homebrew only if you choose to install optional local tools.

## Required macOS Permissions

FlowSound will need:

- System audio capture permission for Core Audio taps.
- `NSAudioCaptureUsageDescription` in the app Info.plist.
- Apple Events / Automation permission to control Music or Spotify.
- Hardened runtime and signing configuration before distributing outside local development.

If App Sandbox is enabled, Apple Events control of Music and Spotify must be tested carefully because sandboxing changes automation requirements.

Launch at login uses `SMAppService.mainApp`. Preferences only updates the login item when the checkbox value changes. Local `.build/FlowSound.app` builds can report `notFound` before registration or `requiresApproval` after registration; FlowSound treats `notFound` as a state where registration can still be attempted. Release validation should still use a signed and installed app bundle.

## Testing

Run automated tests:

```sh
swift test
```

Build a local `.app` bundle:

```sh
scripts/build-app.sh
open .build/FlowSound.app
```

`scripts/build-app.sh` reads `VERSION` and injects it into the generated app bundle `Info.plist`, so the About window and Finder bundle metadata use the same release marker.

Build a release archive and checksum:

```sh
scripts/package-release.sh
ls dist/
```

Release packaging fails if the built bundle version does not match `VERSION` or if `CHANGELOG.md` does not contain a matching release section.

Unsigned release archives are useful for development and testers. Public releases should be signed with a Developer ID Application certificate and notarized by Apple. A local `Apple Development` certificate is not enough for the normal public Gatekeeper experience.

FlowSound is a menu bar app. It does not appear in the Dock and does not open a main window on launch. After opening it, look for the FlowSound glyph in the macOS menu bar.

If the process is running but no menu bar item is visible, check the diagnostics log:

```sh
cat ~/Library/Logs/FlowSound/FlowSound.log
```

On macOS 26, System Settings > Menu Bar > Allow in the Menu Bar is not a reliable way to discover this development build. FlowSound is currently launched from `.build/FlowSound.app`, is not installed as a login item, and is not packaged as a signed release app. The app should still create an `NSStatusItem` while running, but the settings list may not include it.

The menu bar icon uses generated transparent template assets extracted from the wave-and-note glyphs. macOS tints these assets automatically for light and dark menu bars. The activated icon comes from `FlowSound-iCon.png`; the deactivated icon comes from `FlowSound-Deactivate-iCon.png`.

The source `FlowSound-iCon.png` is also split into `Assets/FlowSoundLogoDarkBackground.png` and `Assets/FlowSoundLogoLightBackground.png`; keep the full wordmark for About, marketing, or installer screens. The source `FlowSound-Deactivate-iCon.png` is split into `Assets/FlowSoundDeactivateLightBackground.png` and `Assets/FlowSoundDeactivateDarkBackground.png`.

The app icon is generated as `Assets/FlowSound.icns` during packaging and copied into the app bundle. Finder may cache app icons; if the app icon still looks blank after rebuilding, rename or move the rebuilt `.app`, or relaunch Finder.

## Preferences

Open `Preferences...` from the menu bar menu to configure:

- General: language, music app, timing, and launch at login.
- Monitoring: audio monitoring mode, watched app bundle identifiers, and excluded app bundle identifiers.
- Tools: recently detected audio sources, diagnostics window, and diagnostics log path.
- Tools: adapter profile import/export for inspecting and sharing experimental or community adapter metadata.

Adapter profiles currently describe identity, support level, bundle identifiers, declared capabilities, permissions, and notes. They do not contain executable control scripts and cannot add support for a brand-new player by themselves. Import reads `.json` profile files from `~/Library/Application Support/FlowSound/AdapterProfiles`; if the folder is empty, FlowSound opens it in Finder so you can place local profile files there.

FlowSound validates bundle identifiers before saving. Invalid values are ignored and duplicates are removed. An empty watched list falls back to Safari and Telegram; an empty excluded list falls back to Apple Music, FlowSound, and common macOS notification services. The selected music app is always excluded from all-apps monitoring. Saving Preferences restarts the Core Audio process tap when FlowSound is active.

The Tools tab keeps the raw bundle identifier workflow usable: play audio in another app, refresh Recently Detected Audio Sources, then copy the displayed bundle identifier into Watched apps or Excluded apps when needed. The list keeps sources detected in the last 3 minutes and marks each as watched, excluded, selected music app, or just detected.

Notifications are mixed on macOS. Some alert sounds come from system notification services such as `com.apple.usernoted`; some apps play their own sounds from their own process. The excluded list can suppress system notification services by default, and you can add a noisy app bundle identifier manually if you prefer to ignore that app entirely.

Safari is special-cased in watched-app-only mode because website audio is commonly emitted by WebKit helper processes instead of the `com.apple.Safari` main app process. Keeping `com.apple.Safari` in Preferences automatically expands the active Core Audio watch list to include `com.apple.WebKit.GPU`, `com.apple.WebKit.WebContent`, `com.apple.WebKit.Networking`, and `com.apple.SafariPlatformSupport.Helper`.

## Detection Timing

FlowSound does not poll audio volume every 0.1 seconds. Core Audio pushes captured audio buffers into FlowSound through the process tap IO callback. FlowSound computes RMS for those buffers and records the latest audible time.

A 0.1 second timer checks whether the current active signal has gone quiet. Brief low-RMS buffers do not reset the active candidate immediately; FlowSound allows a 0.75 second gap so normal video/music dynamics can still satisfy the 1 second active duration. A separate 0.5 second process-output poll is used for diagnostics, and as a fallback signal only in `Only watched apps` mode. In `All apps except music` mode, active and quiet decisions use the RMS tap so stale WebKit process-output state does not stretch the quiet duration.

On macOS 26 and newer, FlowSound configures Core Audio taps by bundle identifier and enables process restoration for apps that restart. On macOS 15-25, FlowSound configures taps with currently available Core Audio process object IDs because bundle-ID tap configuration is not available there. This supports macOS 15+, but if a watched or excluded app starts after the tap is created, toggling FlowSound off and on or saving Preferences recreates the tap with the current process list.

Launch-at-login registration is only attempted when macOS reports FlowSound as not registered. If System Settings already shows a pending approval state, saving Preferences again will not register another login item.

When new app audio interrupts a restore, FlowSound preserves the original restore volume and fades down from the selected music app's current in-progress volume. This prevents a partial fade, including a temporary volume of `0`, from becoming the next restore target.

Useful commands for finding bundle identifiers:

```sh
osascript -e 'id of app "Safari"'
mdls -name kMDItemCFBundleIdentifier -r /Applications/Safari.app
```

Recommended tests for the first implementation:

- Unit tests for the state machine.
- Unit tests for threshold timing and quiet-window timing.
- Unit tests for music app command generation.
- Manual integration tests with Safari media playback in all-apps and watched-app-only modes.
- Manual integration tests with Telegram notification sounds and media playback in all-apps mode.
- Manual permission tests on a fresh macOS user account.

Early testing should prioritize false positives, user manual pause handling, and permission failures.

## References

- Apple Developer: [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps)
- Apple Developer: [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- Apple Developer: [NSAudioCaptureUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription)
- Apple Developer: [AppleScript commands reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)
