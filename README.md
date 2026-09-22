# FlowSound

FlowSound is a macOS menu bar app that keeps Apple Music or Spotify playing as background music, then automatically fades and pauses it when other apps start playing audio. When those apps become quiet again, FlowSound resumes the selected music app and fades it back to the previous volume. Netease Cloud Music is available as an experimental adapter.

The target platform is macOS 15+. FlowSound uses Core Audio process taps for outgoing process audio detection. On macOS 26 and newer it can configure taps by bundle identifier; on macOS 15 it tracks process object IDs and rebuilds the tap when relevant processes change.

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
- Live diagnostics with a restore countdown, permission shortcuts, retry, and an advanced section for manual simulation.
- Split logo assets generated from `FlowSound-iCon.png`, including dark-background, light-background, and menu bar template variants.
- A compact About window with the application icon, version and a short description.
- A localized English and Simplified Chinese interface selected from system language, defaulting to English.
- A native Settings toolbar with General, Applications, Sound, and Tools panes.
- Language selection with System, English, and Simplified Chinese options.
- A Tools panel that lists recently detected audio sources from the last 3 minutes with application name, bundle identifier and watched/excluded status.
- Quick actions in Tools to add recently detected apps to a watched/excluded draft, applied with Save.
- A generated `.icns` app icon bundled into `FlowSound.app`.
- Default activation on launch, with manual Activate / Deactivate control from the menu bar.
- Active and deactivated menu bar icons generated from the supplied icon artwork.
- App bundle packaging with Apple Events and system audio capture usage descriptions.

The default monitoring mode listens to all app audio except the selected music app, FlowSound, common macOS notification services, and known system audio services such as `systemsoundserverd`. You can edit exclusions or switch to watched-app-only mode in Preferences.

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
- Xcode with a recent macOS SDK. The minimum build toolchain is Xcode 26 / Swift 6.2; this development version has also been compiled with Xcode 27 / the macOS 27 SDK.
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
ls dist/$(cat VERSION)/test/
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

The source `FlowSound-iCon.png` is also split into `Assets/FlowSoundLogoDarkBackground.png` and `Assets/FlowSoundLogoLightBackground.png`; keep the full wordmark for marketing or installer screens. About uses the app icon. The source `FlowSound-Deactivate-iCon.png` is split into `Assets/FlowSoundDeactivateLightBackground.png` and `Assets/FlowSoundDeactivateDarkBackground.png`.

The app icon is checked in as `Assets/FlowSound.icns` and copied into the app bundle during packaging. Finder may cache app icons; if the app icon still looks blank after rebuilding, rename or move the rebuilt `.app`, or relaunch Finder.

## Preferences

Open `Settings…` from the menu bar menu (or press Command-comma while FlowSound is active) to configure:

- General: music app, language, and launch at login.
- Applications: listening mode and separate watched/ignored application lists with names, icons, counts and aligned removal controls. The music player and FlowSound are summarized as always ignored.
- Sound: fade and quiet timing with sliders plus exact numeric inputs, and detection sensitivity.
- Tools: recently detected audio sources, diagnostics window, and diagnostics log path.
- Tools > Community adapters: profile import/export for inspecting and sharing experimental or community adapter metadata.

Adapter profiles currently describe identity, support level, bundle identifiers, declared capabilities, permissions, and notes. They do not contain executable control scripts and cannot add support for a brand-new player by themselves. Import reads `.json` profile files from `~/Library/Application Support/FlowSound/AdapterProfiles`; if the folder is empty, FlowSound opens it in Finder so you can place local profile files there.

FlowSound validates bundle identifiers and known Core Audio system process identifiers before saving. Invalid values are ignored and duplicates are removed. Explicitly empty lists stay empty after Save, including deleting the final app. Defaults are used for missing preferences and can be restored with Reset + Save. The selected music app is always excluded from all-apps monitoring. Saving changed monitoring rules or detection parameters restarts the Core Audio process tap when FlowSound is active. Language, fade timing, and unchanged saves do not rebuild the tap.

The Tools tab keeps the raw bundle identifier workflow usable: play audio in another app, refresh Recently Detected Audio Sources, then add the displayed app to the Watched or Excluded draft directly from its row when needed. Click Save to apply the draft. The list keeps sources detected in the last 3 minutes and marks each as watched, excluded, selected music app, or just detected.

Notifications are mixed on macOS. Some alert sounds come from system notification services such as `com.apple.usernoted`; some apps play their own sounds from their own process. The excluded list can suppress system notification services by default, and you can add a noisy app bundle identifier manually if you prefer to ignore that app entirely.

Safari is special-cased in watched-app-only mode because website audio is commonly emitted by WebKit helper processes instead of the `com.apple.Safari` main app process. Keeping `com.apple.Safari` in Preferences automatically expands the active Core Audio watch list to include `com.apple.WebKit.GPU`, `com.apple.WebKit.WebContent`, `com.apple.WebKit.Networking`, and `com.apple.SafariPlatformSupport.Helper`. Excluded apps still win after this expansion, so a WebKit helper listed in Excluded apps is removed from the effective watch list.

The native toolbar and controls follow the system appearance on the running macOS version. See [the design baseline](docs/DESIGN.md) for layout, accessibility and visual acceptance conventions.

## Reliability and Settings

Preferences uses a single draft: application pickers, recent-source actions, raw identifier edits, and Reset only change the draft. Save applies it; Cancel discards it. Applications shows separate watched and ignored columns with app names, icons and fixed removal buttons; bundle identifiers remain under Advanced rules. Exclusions take precedence over watched rules and Safari helper expansion.

Open Diagnostics from the menu or Preferences > Tools to see audio monitoring health, the latest player-control result, Accessibility and login-item status, and the remaining quiet countdown. Opening diagnostics does not request permissions or send playback commands. Automation remains “not yet verified” until a real operation succeeds. The captured stream is a mix; recent output processes are diagnostic hints, not proof of which app triggered a pause.

FlowSound restores only its own completed pause for the same player instance. A player restart, manual playback, or an observable manual volume change relinquishes restoration. Official players must still be paused at volume zero before restore. Netease cannot expose an exact volume, so manual volume intervention cannot be detected reliably; relative restore remains approximate. Repeated interruption uses the most recent relative step count rather than replaying an older, larger count.

Deactivate, Quit, or changing players cancels automation and discards ownership; it does not force playback or change the old player's remaining volume. If a command fails after partially changing volume, inspect the player and adjust it manually before retrying. Commands are serialized and bounded (normally 5 seconds, fade duration plus 5 seconds for official fades). User actions occurring between observation and a command cannot be detected atomically through Apple Events.

No captured audio is written to disk. Logs are local and bounded to a current 1 MiB file plus one rotated file. Hardware and permission checks remain separate from unit tests; see [Compatibility and acceptance](docs/COMPATIBILITY.md).

## Detection Timing

FlowSound does not poll audio volume every 0.1 seconds. Core Audio pushes captured audio buffers into FlowSound through the process tap IO callback. FlowSound computes RMS for those buffers and records the latest audible time.

A 0.1 second timer checks whether the current active signal has gone quiet. Brief low-RMS buffers do not reset the active candidate immediately; FlowSound allows a 0.75 second gap so normal video/music dynamics can still satisfy the 1 second active duration. A separate 0.5 second process-output poll is used for diagnostics, and as a fallback signal only in `Only watched apps` mode. In `All apps except music` mode, active and quiet decisions use the RMS tap so stale WebKit process-output state does not stretch the quiet duration.

On macOS 26 and newer, FlowSound configures Core Audio taps by bundle identifier and enables process restoration for apps that restart. On macOS 15, FlowSound configures taps with Core Audio process object IDs and rebuilds the tap when the relevant process list changes. On all supported systems it rebuilds its private tap after output-device/format changes and sleep/wake, with a bounded retry policy. See [the compatibility matrix](docs/COMPATIBILITY.md) for what has actually been validated.

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
