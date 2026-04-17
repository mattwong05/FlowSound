# FlowSound

FlowSound is a macOS menu bar app that keeps Apple Music playing as background music, then automatically fades and pauses it when selected apps start playing audio. When those apps become quiet again, FlowSound resumes Apple Music and fades it back to the previous volume.

The target platform is macOS 26+. The core APIs needed for the MVP are already available on modern macOS, including Core Audio process taps for outgoing process audio detection.

## Current Implementation

The current build is a native Swift menu bar app with:

- One-click enable and disable from the menu bar.
- A tested ducking state machine.
- Apple Music control through AppleScript and `osascript`.
- Fade-out, pause, play, and fade-in behavior.
- Manual menu items to simulate watched audio and quiet periods while Core Audio process tap monitoring is implemented.
- Split logo assets generated from `FlowSound-iCon.png`, including dark-background, light-background, and menu bar template variants.
- An About window that chooses the light or dark FlowSound logo artwork based on appearance.
- A Preferences window for active threshold, active duration, quiet duration, fade-out duration, fade-in duration, and menu bar text visibility.
- A generated `.icns` app icon bundled into `FlowSound.app`.
- Default activation on launch, with manual Activate / Deactivate control from the menu bar.
- Active and deactivated menu bar icons generated from the supplied icon artwork.
- App bundle packaging with Apple Events and system audio capture usage descriptions.

The automatic Core Audio process tap monitor is still the next implementation step. The app is structured so that monitor can replace the current manual test monitor without changing Apple Music control or state machine logic.

## MVP Behavior

- Watch a configurable whitelist of apps, initially Safari and Telegram.
- Treat a whitelisted app as active only after it produces audio above a threshold for 0.5 seconds.
- Fade Apple Music volume down over 3 seconds.
- Pause Apple Music after the fade-out completes.
- Resume Apple Music after 5 seconds of quiet.
- Fade Apple Music volume back to the volume captured before ducking.
- Provide a one-click menu bar toggle to enable or disable the service.
- Start activated when the app launches.

## Technical Approach

FlowSound is implemented as a native Swift app:

- App shell: AppKit menu bar integration.
- Audio detection: Core Audio process taps through the `AudioActivityMonitor` boundary.
- Signal analysis: short-window RMS or peak detection.
- Apple Music control: AppleScript executed through a narrow Swift wrapper.
- Coordination: explicit state machine to avoid repeated pause/resume loops.
- Configuration: local settings for whitelist, thresholds, fade durations, and enablement.

See [ARCHITECTURE.md](ARCHITECTURE.md) and [docs/TECHNICAL_FEASIBILITY.md](docs/TECHNICAL_FEASIBILITY.md) for details.

## Required Environment

For development:

- macOS 26 or newer for the product target.
- Xcode with the macOS 26 SDK.
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
- Apple Events / Automation permission to control Music.
- Hardened runtime and signing configuration before distributing outside local development.

If App Sandbox is enabled, Apple Events control of Music must be tested carefully because sandboxing changes automation requirements.

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

- Active threshold.
- Active duration.
- Quiet duration.
- Fade-out duration.
- Fade-in duration.
- Whether the menu bar shows the `FlowSound` text label or only the icon.

Recommended tests for the first implementation:

- Unit tests for the state machine.
- Unit tests for threshold timing and quiet-window timing.
- Unit tests for Apple Music command generation.
- Manual integration tests with Safari media playback.
- Manual integration tests with Telegram notification sounds and media playback.
- Manual permission tests on a fresh macOS user account.

Early testing should prioritize false positives, user manual pause handling, and permission failures.

## References

- Apple Developer: [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps)
- Apple Developer: [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- Apple Developer: [NSAudioCaptureUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription)
- Apple Developer: [AppleScript commands reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)
