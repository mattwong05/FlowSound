# FlowSound

FlowSound is planned as a macOS menu bar app that keeps Apple Music playing as background music, then automatically fades and pauses it when selected apps start playing audio. When those apps become quiet again, FlowSound resumes Apple Music and fades it back to the previous volume.

The target platform is macOS 26+. The core APIs needed for the MVP are already available on modern macOS, including Core Audio process taps for outgoing process audio detection.

## MVP Behavior

- Watch a configurable whitelist of apps, initially Safari and Telegram.
- Treat a whitelisted app as active only after it produces audio above a threshold for 0.5 seconds.
- Fade Apple Music volume down over 3 seconds.
- Pause Apple Music after the fade-out completes.
- Resume Apple Music after 5 seconds of quiet.
- Fade Apple Music volume back to the volume captured before ducking.
- Provide a one-click menu bar toggle to enable or disable the service.

## Technical Approach

FlowSound should be implemented as a native Swift app:

- App shell: SwiftUI plus AppKit menu bar integration.
- Audio detection: Core Audio process taps.
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
