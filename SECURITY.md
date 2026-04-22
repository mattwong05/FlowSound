# Security

## Release Trust Model

FlowSound is open source and release artifacts should be reproducible from the tagged source as much as practical.

Official releases should include:

- A GitHub Release tied to a version tag.
- `FlowSound-<version>.zip`.
- `SHA256SUMS.txt`.
- Release notes that list supported macOS versions, supported music apps, and required permissions.
- A linked GitHub Actions run for the release build.

Unsigned tester builds should still be ad-hoc signed after the `.app` bundle is assembled so macOS can verify bundle integrity. Ad-hoc signing does not replace Developer ID signing or notarization.

When a Developer ID certificate is available, public releases should also be:

- Signed with a Developer ID Application certificate.
- Notarized by Apple.
- Stapled before packaging.

## Certificate Requirements

An `Apple Development` certificate is useful for local development and testing. It is not the right certificate for public macOS distribution outside the Mac App Store.

For public releases with the normal Gatekeeper experience, use a Developer ID Application certificate from the Apple Developer Program and notarize the app.

## Verifying Downloads

After downloading a release zip and checksum file:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

The command should report `OK` for the downloaded archive.

## Reporting Security Issues

Please do not open a public issue for sensitive security reports.

Send a private report to the repository owner, or use GitHub private vulnerability reporting if it is enabled for the repository.

Include:

- FlowSound version.
- macOS version.
- Steps to reproduce.
- Whether the issue affects permissions, Apple Events, audio capture, release artifacts, or update/install behavior.

## Security Boundaries

FlowSound should keep these boundaries explicit:

- Core Audio process tap logic stays isolated from UI code.
- Music app automation stays behind `MusicController`.
- Permission failures should be visible to the user.
- FlowSound should not resume the selected music app unless FlowSound paused it.
- FlowSound should not add network behavior without documentation and review.
