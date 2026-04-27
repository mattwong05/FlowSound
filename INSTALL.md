# Install FlowSound

FlowSound is a native macOS menu bar app for Apple Music and Spotify, with experimental Netease Cloud Music support.

## Requirements

- macOS 15 or newer.
- Apple Music, Spotify, or Netease Cloud Music installed and available.
- Permission to capture system audio activity.
- Permission to control Music through Apple Events / Automation.

FlowSound officially controls Apple Music and Spotify through local AppleScript. Netease Cloud Music is experimental and uses menu commands, Accessibility permission, and Core Audio output feedback because it does not expose the same native playback and volume AppleScript interface.

For Netease Cloud Music, open System Settings > Privacy & Security > Accessibility and allow FlowSound. This is needed so FlowSound can click Netease's Controls menu in the background. Volume restore is approximate because Netease exposes relative volume steps, usually about 5%, not an exact readable volume.

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
- Automation permission, so FlowSound can control the selected music app.
- Accessibility permission for experimental menu-command adapters such as Netease Cloud Music.
- Login Item approval, only if you enable Launch at Login in Preferences.

FlowSound does not record audio, save captured audio, upload data, or use analytics.

## Unsigned Builds

Unsigned builds are intended for developers and testers. FlowSound ad-hoc signs local app bundles so the bundle is internally consistent, but unsigned release archives may still show Gatekeeper warnings and may require manual approval in System Settings.

If macOS still blocks an unsigned tester build downloaded from GitHub, verify the checksum first, then remove the download quarantine attribute:

```sh
xattr -dr com.apple.quarantine /Applications/FlowSound.app
```

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
