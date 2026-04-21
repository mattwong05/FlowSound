# FlowSound VERSION

FlowSound is a native macOS menu bar app that fades and pauses Apple Music when other apps start playing audio, then restores Apple Music after things become quiet again.

## Compatibility

- macOS 26 or newer.
- Apple Music only.

## Download

- `FlowSound-VERSION.zip`
- `SHA256SUMS.txt`

Verify the download:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## Required Permissions

FlowSound may ask macOS for:

- System audio capture permission to detect app audio activity.
- Automation permission to control Apple Music playback and volume.
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

- FlowSound controls Apple Music only.
- Unsigned builds may require manual Gatekeeper approval.
- Launch at Login should be validated with signed and installed builds.
