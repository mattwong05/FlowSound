# Compatibility and release acceptance

This is an evidence record, not a blanket compatibility claim. Minimum deployment target remains macOS 15. Public packages contain Apple Silicon (arm64) and Intel (x86_64) slices. Compiler/SDK version, host OS, runtime OS, app signature and hardware evidence are distinct.

## Current local evidence — 0.17.0 development, 2026-09-23

- Host: macOS 26.6.2 on arm64.
- Toolchain: Xcode 27.0 (27A266a), Swift 6.4, macOS 27.0 SDK.
- Packaging passes the selected SDK explicitly and checks each Mach-O slice's SDK metadata independently from the macOS 15 deployment target. A successful SDK 27 build does not establish macOS 27 runtime behavior.
- All 67 Swift tests passed. Service, settings, signal/PCM, lifecycle fault-injection and command-runner tests use fakes or local non-player commands. They do not open audio devices, grant TCC permissions, or control real players.
- Native UI previews use a fake adapter, a manual monitor and isolated temporary preferences. Sixteen English/Chinese preview captures and two final rule-removal captures were inspected; draft changes, Reset, removal and Cancel were checked without persistent settings writes. They establish layout/draft behavior only.
- All 24 isolated release safeguard checks passed, covering configuration, stable release prerequisites, changelog/version checks, per-architecture SDK metadata and preservation of existing artifacts.
- Universal app build, bundle metadata, ad-hoc signature, archive checksum and packaging safeguard checks are software/package evidence only.
- Developer ID signing, notarization, Gatekeeper acceptance, real-player behavior, energy use and macOS 15/27 runtime behavior remain **not verified in this implementation session**.

## Runtime acceptance matrix

Record the exact OS build, machine/architecture, player version, FlowSound version and signature for each run. Mark each case pass/fail/not tested and attach a concise log excerpt. Do not mark all cases passed based on one SDK build.

| Case | macOS 15 | macOS 26 | macOS 27 |
| --- | --- | --- | --- |
| Fresh signed install and Gatekeeper launch | Not tested | Not tested | Not tested |
| Audio capture: grant, deny, revoke, regrant and Retry | Not tested | Not tested | Not tested |
| Apple Music / Spotify automation permission and complete fade/pause/restore | Not tested | Not tested | Not tested |
| Netease helper TCC identity, Accessibility and both menu languages | Not tested | Not tested | Not tested |
| Pause ownership: manual play, pause, volume change, quit/restart, switching player | Not tested | Not tested | Not tested |
| Built-in output ↔ AirPods ↔ USB DAC, sample rate change, disconnect | Not tested | Not tested | Not tested |
| Sleep/wake and repeated device recovery with no leaked aggregate devices | Not tested | Not tested | Not tested |
| Safari/WebKit restart, app launch after FlowSound, watched/excluded rules | Not tested | Not tested | Not tested |
| Login item grant/deny and repeated unchanged saves | Not tested | Not tested | Not tested |
| Installed UI: EN/ZH, short screen, keyboard, VoiceOver, light/dark | Not tested | Not tested | Not tested |
| 2-hour idle/playback CPU, wakeups, energy impact and fade latency | Not tested | Not tested | Not tested |

macOS 27 UI regression checks include the segmented tab control and NSTextView editing/undo. API availability guards keep the existing macOS 15 path. See Apple's [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes) and [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes).

## Expected failure behavior

- Audio creation failures report a failed monitor, not successful listening. Retry is explicit after a terminal error.
- Device/format/wake changes rebuild only FlowSound's private tap/aggregate, with a finite retry budget. No system output selection or device settings are changed.
- Initial silence requires observed samples; missing samples are not silent PCM. Watched-only process-IO fallback is lower-confidence and cannot identify actual audible sound.
- Restore countdown pauses while monitoring is starting/recovering. A fresh observation is required after reconfiguration.
- User intervention that can be observed relinquishes restore. Apple Events state checks and writes are not atomic across independent user actions. Netease has no exact volume readback and remains experimental.
- Deactivate/Quit/player changes stop further commands and discard ownership. They do not resume a player or forcibly restore a partially changed volume. If a partial command failed, the user may need to adjust the old player's volume manually.
- Missing permissions, menu changes, or stopped sample delivery must end in a readable diagnostic rather than an unbounded command or retry loop.

## Release gate

A stable tag must match VERSION and refer to a clean commit contained in origin/main. Stable packaging requires both architectures, Developer ID Application signing with the Apple Events entitlement, successful notarization, stapling/Gatekeeper checks, and checksums. Those automated checks do not replace the runtime matrix above. Do not promote a test artifact to the default download while required acceptance remains unverified.
