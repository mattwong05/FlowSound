# Technical Feasibility

## Summary

FlowSound is technically feasible as a native macOS 26+ app.

The strongest implementation path is:

1. Use Core Audio process taps to detect outgoing audio from all non-Apple Music apps by default.
2. Use a small signal detector to confirm sustained audio activity.
3. Use AppleScript as a narrow Apple Music control bridge.
4. Use a state machine to coordinate fade-out, pause, quiet detection, resume, and fade-in.

This keeps the hard real-time audio work inside Core Audio and keeps Apple Music automation simple.

## What Is Feasible

### Detecting App Audio

Apple documents Core Audio taps as a way to capture outgoing audio from a process or group of processes. A tap can be configured through `CATapDescription`, including process-based capture and mixdown settings.

For FlowSound, the watcher can create process taps for all apps except Apple Music, FlowSound, and excluded notification services, or for whitelisted apps in watched-app-only mode, read sample buffers through an aggregate device input path, and compute audio activity from the captured samples.

Recommended first detector:

- Convert the buffer to a normalized floating-point stream.
- Compute RMS over short windows, for example 50 ms to 100 ms.
- Mark app audio as audible only when RMS remains above the configured threshold for 1 second.
- Mark the system as quiet only when matching apps remain below threshold for the configured quiet duration, currently 3 seconds by default.

### Controlling Apple Music

Apple Music can be controlled through Apple Events exposed to AppleScript. FlowSound should not put core product logic in AppleScript. Instead, Swift should own the state machine and call a small automation adapter for:

- `play`
- `pause`
- read current player state where available
- read current `sound volume`
- set `sound volume`

The safest MVP approach is to execute short AppleScript commands through a Swift wrapper and handle failures explicitly.

### Menu Bar Control

A one-click enable/disable switch is straightforward with a menu bar app. Disabling should:

- Stop active taps.
- Cancel timers.
- Cancel in-progress fade operations.
- Avoid automatically resuming Music unless FlowSound paused it and the user explicitly chooses that behavior.

### Launch at Login

FlowSound can use `SMAppService.mainApp` for launch-at-login registration. Local app bundles may report `notFound` before registration and `requiresApproval` after registration. FlowSound should treat `notFound` as registrable, avoid repeated registration while approval is pending, and validate final behavior with a signed and installed app bundle.

## Main Risks

### Permission Friction

Core Audio taps require system audio capture permission and an `NSAudioCaptureUsageDescription` Info.plist string. Apple Music automation requires Apple Events permission. The first-run experience must explain both clearly.

### Apple Music Automation Reliability

AppleScript is practical for simple commands, but it is still interprocess automation. Commands can fail when Music is not running, permission is denied, the app is busy, or macOS changes automation behavior.

Mitigation:

- Keep commands short.
- Retry only where safe.
- Surface permission errors in the menu.
- Preserve the user's last known target volume.
- Keep the captured restore target stable when restore is interrupted by new app audio.
- Do not force resume if FlowSound did not pause Music.

### False Positives

Notification sounds from Telegram or short UI sounds can trigger the detector if the threshold is too sensitive.

Mitigation:

- Require sustained audio for 1 second.
- Allow short low-RMS gaps before resetting the active candidate.
- Exclude common system notification services in all-apps mode.
- Expand Safari to WebKit helper bundle identifiers because website audio may not originate from the Safari main process.
- Use per-app thresholds later if needed.
- Allow users to tune the active threshold and active duration.

### User Intent

FlowSound must distinguish system actions from user actions. If the user manually pauses Apple Music, FlowSound should not resume it just because watched apps become quiet.

Mitigation:

- Track `pausedByFlowSound`.
- Sample Music state before ducking.
- Resume only when Music was playing before FlowSound intervened.

## Recommended MVP Scope

Build the first version as a local native app with:

- All-apps-except-Apple-Music monitoring mode.
- Safari and Telegram watched-app-only fallback whitelist.
- Fixed defaults for thresholds and fades.
- Menu bar enable/disable.
- Visible status: disabled, listening, ducking, paused by FlowSound, restoring, permission needed.
- Local logs for state transitions and automation failures.

Do not include advanced UI, per-app configuration, launch-at-login, or distribution packaging until the core detection and control loop feels reliable.

## Current Implementation Status

Version 0.11.x contains the native menu bar shell, default activation on launch, active and deactivated menu bar icons, Core Audio process tap monitoring, all-apps-except-Apple-Music monitoring mode, excluded notification services, watched-app-only mode, Safari WebKit helper expansion, process-output fallback diagnostics, RMS activity detection, state machine, Apple Music automation adapter, app bundle packaging, release archive packaging, checksums, logo assets, app icon, preferences window, editable watched app whitelist, launch-at-login control, and manual audio activity simulation.

This means the current build can validate system audio capture permission prompts, Apple Music permission prompts, fade behavior, pause/resume behavior, menu controls, state transitions, all-apps monitoring, default Safari / Telegram watched-app-only detection, and custom watched app bundle identifiers.

macOS 26 menu bar behavior needs explicit hardening. Development builds launched from `.build/FlowSound.app` may not appear in System Settings > Menu Bar > Allow in the Menu Bar even when the app process is running and an `NSStatusItem` is created. Release validation should include an installed, signed app bundle and a fresh user account.

Public release validation should use a Developer ID Application certificate and Apple notarization. Unsigned release archives can still be useful for testers, but they should be ad-hoc signed for bundle integrity, labeled as unsigned, and may require manual Gatekeeper approval. CI release tests should avoid fixed timing assumptions for async service state transitions because hosted runners can be slower than local machines.

## Feasibility Verdict

The product is feasible. The highest-risk area is not the state machine or menu bar app; it is reliable macOS permission handling plus Apple Music automation behavior. The MVP should therefore validate the full permission and automation loop before investing in a larger settings UI.

## Sources

- Apple Developer: [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps)
- Apple Developer: [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- Apple Developer: [NSAudioCaptureUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription)
- Apple Developer: [AppleScript commands reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)
