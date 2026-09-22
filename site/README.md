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

## Release, header and screenshots

The primary action links to GitHub's `releases/latest`, currently **0.18.0**, the official default release. FlowSound intentionally uses ad-hoc signing without Apple notarization; the installation guide explains first-launch approval in macOS Privacy & Security. Signing method and release channel are separate choices. Do not claim macOS 27 runtime validation without evidence.

The header stays on one line: the original menu-bar mark plus a text wordmark, navigation links, and a small globe button for language selection. Below 600px, navigation moves into a separate menu. Menus support keyboard focus, Escape, outside-click dismissal and mutually exclusive opening. Keep the app mark as a CSS mask so it follows the system appearance without padding from the full logo artwork.

The small globe, menu and check icons are unmodified SVGs from [Lucide](https://github.com/lucide-icons/lucide/tree/main/icons), bundled locally under `assets/` with `LUCIDE-LICENSE`. The website needs no icon runtime or CDN.

`assets/settings-{en|zh}-{light|dark}.png` are exact native AppKit captures from `scripts/preview-ui.sh`, with sample rules on macOS 26. Language selection changes both copy and screenshot, and the system color scheme chooses its appearance. Keep the screenshots aligned with the version described on the page. The existing demo video shows the audio-focus workflow; it is not a recording of every current settings screen.

Before deployment, check English and Simplified Chinese in light and dark appearances, at desktop and mobile widths (including the 782px review viewport). Confirm release and installation links, full-size screenshot links, header menu behavior, keyboard focus, and the absence of horizontal overflow. Production `main` tracks the official application release and deploys the static site through Cloudflare Pages.
