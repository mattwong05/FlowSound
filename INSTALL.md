# Install FlowSound

FlowSound is a native macOS menu bar app for Apple Music and Spotify, with experimental Netease Cloud Music support.

## Requirements

- macOS 15 or newer.
- Apple Music, Spotify, or Netease Cloud Music installed and available.
- Permission to capture system audio activity.
- Permission to control Music through Apple Events / Automation.

FlowSound officially controls Apple Music and Spotify through local AppleScript. Netease Cloud Music is experimental and uses menu commands, Accessibility permission, and Core Audio output feedback because it does not expose the same native playback and volume AppleScript interface.

For Netease Cloud Music, open System Settings > Privacy & Security > Accessibility and allow FlowSound. This is needed so FlowSound can click Netease's Controls menu in the background. Volume restore is approximate because Netease exposes relative volume steps, usually about 5%, not an exact readable volume.

If Accessibility is already enabled but Netease still fails with `-1719` or an assistive access error, remove FlowSound from the Accessibility list and add the current rebuilt app again. This can happen with local ad-hoc signed builds.

## Recommended Install

1. Open the [latest GitHub Release](https://github.com/mattwong05/FlowSound/releases/latest).
2. Download the universal arm64/x86_64 `FlowSound-<version>.zip`.
3. Download `SHA256SUMS.txt`.
4. Verify the checksum:

   ```sh
   shasum -a 256 -c SHA256SUMS.txt
   ```

5. Unzip `FlowSound-<version>.zip`.
6. Move `FlowSound.app` to `/Applications`.
7. Open `FlowSound.app`. If macOS blocks it because the developer cannot be verified, follow the manual approval steps below.
8. Approve the macOS permission prompts.

FlowSound lives in the menu bar. It does not appear in the Dock.

## First Run Permissions

macOS may ask for:

- Audio capture permission, so FlowSound can detect whether other apps are producing audio.
- Automation permission, so FlowSound can control the selected music app.
- Accessibility permission for experimental menu-command adapters such as Netease Cloud Music.
- Login Item approval, only if you enable Launch at Login in Preferences.

FlowSound does not record audio, save captured audio, upload data, or use analytics.

## Manual first-launch approval

The official FlowSound release uses ad-hoc signing and is not notarized by Apple. This is the project's normal distribution method. Ad-hoc signing checks the bundle's integrity but does not establish a Developer ID identity, so macOS may block the first launch.

After downloading from the GitHub release and verifying its checksum:

1. Open `/Applications/FlowSound.app` once and dismiss the blocked-app dialog.
2. Open **System Settings > Privacy & Security**.
3. Find the FlowSound blocked-app message, choose **Open Anyway**, and confirm with your password or Touch ID if requested.
4. Confirm **Open** in the next dialog. FlowSound then appears in the menu bar.

These steps approve this app. See [Apple's instructions for opening an app from an unknown developer](https://support.apple.com/guide/mac-help/mh40616/mac). If the button is unavailable on a managed Mac, its administrator may restrict manual approval.

首次启动如被 macOS 拦截，请先尝试打开一次 FlowSound，再进入“系统设置 → 隐私与安全”，找到 FlowSound 提示并点击“仍要打开”，按提示确认。正式版采用 ad-hoc 签名，未经 Apple 公证；无需关闭系统的 Gatekeeper。

## Uninstall

1. Quit FlowSound from the menu bar.
2. Remove FlowSound from System Settings > General > Login Items if enabled.
3. Delete `/Applications/FlowSound.app`.
4. Optional: remove local settings and logs:

   ```sh
   defaults delete com.flowsound.FlowSound
   rm -rf ~/Library/Logs/FlowSound
   ```

## Development test artifacts

Local packaging writes `dist/<version>/test/`. Official stable packaging writes `dist/<version>/stable/`; it is also ad-hoc signed by default. Optional Developer ID signing and notarization must be explicitly configured. The release notes and `BUILD_INFO.txt` identify the distribution method, app architectures and build toolchain.

Use the menu's Diagnostics action for monitoring health, permission shortcuts, and Retry after fixing a reported error. Permissions and player control must be verified in the installed distributed app; a successful build or an ad-hoc helper execution does not prove TCC authorization. See [the acceptance matrix](docs/COMPATIBILITY.md).
