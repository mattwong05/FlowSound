# FlowSound Website

This is the static landing page for FlowSound.

## Cloudflare Pages

Use these settings:

- Framework preset: `None`
- Build command: leave empty
- Build output directory: `site`
- Production branch: `main`

Recommended custom domain:

```text
flowsound.youseminar.cn
```

The page supports English and Simplified Chinese. It defaults to English unless the browser language starts with `zh`; users can switch manually. The product copy should stay aligned with the app's current support matrix: macOS 15+, official Apple Music and Spotify support, experimental Netease Cloud Music support, and local-first permission handling.

## Release channels and screenshots

The primary action currently links to the **0.18.0 public preview** release at `preview-0.18.0`. It is ad-hoc signed and not notarized; its installation limits appear beside the download action and in the FAQ. The separate stable action points to GitHub's `releases/latest`, currently 0.15.1. Preview publication must not move GitHub's latest stable release or claim macOS 27 runtime validation.

`assets/settings-{en|zh}-{light|dark}.png` are exact native AppKit captures from `scripts/preview-ui.sh`, with sample rules on macOS 26. Language selection changes both copy and screenshot, and the system color scheme chooses its appearance. Keep the screenshots aligned with the version described on the page. The existing demo video shows the audio-focus workflow; it is not a recording of every current settings screen.

Before deployment, check English and Simplified Chinese in light and dark appearances, at desktop and mobile widths. Confirm both release links, full-size screenshot links, keyboard focus, and the absence of horizontal overflow. Production `main` can receive these site changes independently while preview application code remains on `dev`.
