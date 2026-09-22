# FlowSound VERSION

FlowSound is a native macOS menu bar app that fades and pauses Apple Music or Spotify when other apps start playing audio, then restores the selected music app after things become quiet again. Netease Cloud Music is available as an experimental adapter.

## Compatibility

- macOS 15 or newer; universal Apple Silicon (arm64) and Intel (x86_64) app.
- Compilation with the macOS 27 SDK does not establish macOS 27 runtime acceptance; see `docs/COMPATIBILITY.md`.
- Apple Music, Spotify, or experimental Netease Cloud Music.

## Download

- `FlowSound-VERSION.zip`
- `SHA256SUMS.txt`
- `BUILD_INFO.txt`

Verify the download:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## Required Permissions

FlowSound may ask macOS for:

- System audio capture permission to detect app audio activity.
- Automation permission to control the selected music app.
- Accessibility permission for experimental menu-command adapters such as Netease Cloud Music.
- Login Item approval if Launch at Login is enabled.

FlowSound does not record audio, upload data, use analytics, or contact a server.

## Install

1. Download and verify the zip.
2. Unzip `FlowSound-VERSION.zip`.
3. Move `FlowSound.app` to `/Applications`.
4. Open FlowSound and approve the permission prompts.

See `INSTALL.md` for details.

## Changes

- Replace this section with the release changelog.

## Known Limitations

- Apple Music and Spotify are official support paths. Netease Cloud Music is experimental and can break if its menu layout changes.
- Netease Cloud Music requires Accessibility permission so FlowSound can click its Controls menu. Its volume restore is approximate because Netease exposes relative volume steps instead of an exact readable volume.
- Adapter profile import/export is local JSON metadata only. FlowSound does not download scripts or make network requests for profiles.
- Test artifacts are ad-hoc signed and may require manual Gatekeeper approval; stable release packaging requires Developer ID signing and notarization.
- Launch at Login should be validated with signed and installed builds.
