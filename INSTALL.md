# Install FlowSound

FlowSound is a native macOS menu bar app for Apple Music.

## Requirements

- macOS 26 or newer.
- Apple Music installed and available.
- Permission to capture system audio activity.
- Permission to control Music through Apple Events / Automation.

FlowSound currently controls Apple Music only. It does not control Spotify, YouTube Music, or other music apps.

## Recommended Install

1. Open the latest GitHub Release.
2. Download `FlowSound-<version>.zip`.
3. Download `SHA256SUMS.txt`.
4. Verify the checksum:

   ```sh
   shasum -a 256 -c SHA256SUMS.txt
   ```

5. Unzip `FlowSound-<version>.zip`.
6. Move `FlowSound.app` to `/Applications`.
7. Open `FlowSound.app`.
8. Approve the macOS permission prompts.

FlowSound lives in the menu bar. It does not appear in the Dock.

## First Run Permissions

macOS may ask for:

- Audio capture permission, so FlowSound can detect whether other apps are producing audio.
- Automation permission, so FlowSound can control Apple Music playback and volume.
- Login Item approval, only if you enable Launch at Login in Preferences.

FlowSound does not record audio, save captured audio, upload data, or use analytics.

## Unsigned Builds

Unsigned builds are intended for developers and testers. They may show Gatekeeper warnings and may require manual approval in System Settings.

Public releases should be signed with a Developer ID Application certificate and notarized by Apple. A local `Apple Development` certificate is not enough for a smooth public install experience.

## Uninstall

1. Quit FlowSound from the menu bar.
2. Remove FlowSound from System Settings > General > Login Items if enabled.
3. Delete `/Applications/FlowSound.app`.
4. Optional: remove local settings and logs:

   ```sh
   defaults delete com.flowsound.FlowSound
   rm -rf ~/Library/Logs/FlowSound
   ```
