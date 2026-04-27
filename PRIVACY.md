# Privacy

FlowSound is designed to be local, simple, and auditable.

## What FlowSound Does

- Detects whether other apps are producing audio.
- Controls the selected music app through local Apple Events or explicit local adapter commands.
- Stores Preferences locally with `UserDefaults`.
- Writes local diagnostic logs to `~/Library/Logs/FlowSound/FlowSound.log`.

## What FlowSound Does Not Do

- Does not record microphone audio.
- Does not save captured system audio.
- Does not upload audio or metadata.
- Does not use analytics.
- Does not include ads.
- Does not contact a server.
- Does not sell or share data.

## Permissions

FlowSound requests system audio capture permission to detect app audio activity. The detector computes audio level information locally and uses it to decide when the selected music app should fade out or restore.

FlowSound requests Automation permission to control Apple Music or Spotify. It sends local commands such as `play`, `pause`, and `set sound volume`.

Experimental adapters such as Netease Cloud Music may also require Accessibility permission because they use menu commands instead of a native AppleScript playback and volume interface. FlowSound keeps adapter profile data local and does not download or execute arbitrary community scripts.

Launch at Login is optional and controlled from Preferences.

## Network

FlowSound has no network feature. If a future version adds any network capability, it must be documented before release.

## Open Source

The source code is published at:

https://github.com/mattwong05/FlowSound

Users can inspect how permissions are used, build FlowSound locally, or compare release artifacts with the tagged source.
