# Interface design

FlowSound should feel clear, quiet and familiar as a native Mac utility. The menu answers “what is happening?”; Settings answers “how should it behave?”; Diagnostics explains failures and recovery. Audio and automation behavior stay behind the existing service boundaries.

## Problem and intended flow

The supplied 0.17.0 screenshot showed removal buttons at different horizontal positions, two list headings inside one scrolling frame, and long explanatory text competing with application names. These made a simple rule list look like an unfinished form.

The redesigned Applications pane presents two independent columns: watched applications and ignored applications. Each has its own heading, count, Add action and scrollable rows. App icons and names identify entries; removal controls align to a fixed trailing edge. A short note explains the monitoring mode and automatic exclusions. Bundle identifiers remain available in a disclosed advanced editor.

The normal flow is: choose the music player, choose monitoring behavior, manage application rules, adjust sound timing if needed, then Save. Changes remain a draft until Save; Cancel discards them. Diagnostic and experimental controls stay outside this everyday path.

## Native structure and controls

- **Settings navigation:** a noncustomizable `NSToolbar` switches General, Applications, Sound and Tools panes, shows the selected pane and updates the window title. This follows Apple's [Settings guidance](https://developer.apple.com/design/human-interface-guidelines/settings).
- **Application rules:** separate `ApplicationRuleColumn` views keep headings outside row content. Current layout uses 52 pt rows and a 28 pt trailing removal control; these are FlowSound layout choices, not Apple requirements. Native symbol buttons have action labels and tooltips. Names take priority over raw identifiers. Empty lists have explicit states. See [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) and [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).
- **Automatic exclusions:** the selected player and FlowSound are summarized as always ignored, rather than offered as editable rules. Their presentation must not imply that removing a redundant identifier enables capture.
- **Sound settings:** sliders support quick adjustments, with exact numeric fields for precise values. Labels, units and validation remain explicit. Popup buttons choose among alternatives; checkboxes retain their existing binary-setting role. See [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) and [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles).
- **Menu bar:** keep the native `NSMenu` compact, with current status and frequent actions first. Configuration opens Settings. This utility does not need a custom dashboard popover. See [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar).
- **Diagnostics:** align labels and values, associate recovery actions with the relevant state, and disclose logs and simulation tools. A visual status must continue to distinguish observed success, pending work and unverified permissions.
- **Visual hierarchy:** use system fonts, semantic text colors, native controls and modest `NSBox` grouping. Content should remain readable without decorative glass layers. Apple reserves Liquid Glass chiefly for navigation and controls above content; see [Materials](https://developer.apple.com/design/human-interface-guidelines/materials).

## macOS 27 and compatibility

Apple's [WWDC26 platform overview](https://developer.apple.com/videos/play/wwdc2026/102/) describes improved Liquid Glass readability, system appearance customization, uniform toolbars, revised window shapes and macOS support for the show-borders accessibility setting. Standard toolbars and controls receive system appearance updates; custom backgrounds should not cover those effects. The [macOS 27 release overview](https://support.apple.com/en-us/127257) confirms these design refinements.

The two-column rules layout and native Settings toolbar are applications of established HIG guidance, not new macOS 27 requirements. FlowSound still targets macOS 15. The user reported that 0.17.0 runs on macOS 26; this is useful launch/runtime feedback, not comprehensive acceptance of the redesign, permissions or audio hardware. SDK availability and native appearance adoption do not establish macOS 27 runtime compatibility.

## Acceptance checklist

Record actual outcomes, OS/build, appearance and evidence in [COMPATIBILITY.md](COMPATIBILITY.md). This checklist defines checks; it does not claim they have passed.

- Inspect every pane and the menu in English and Simplified Chinese, in light and dark appearances. Titles, units, buttons and footers must remain legible without clipping.
- Check empty lists, a single item, many items, missing apps and long names/identifiers. Both columns must scroll independently; headings and actions stay stable; removal controls stay aligned.
- Exercise Add, Remove, mode/player changes, advanced editing, Reset, Save and Cancel. Counts and summaries must match the draft; automatic exclusions must remain clear.
- Check a short available screen height and expanded advanced sections. Every setting and Save/Cancel must remain reachable without overlapping content.
- Use the keyboard through toolbar panes, lists, fields, disclosure controls and actions. Focus order and focus indication must be clear, and standard editing shortcuts must work.
- Use VoiceOver on the running app. Verify pane names, row identities, action labels, slider values and diagnostic states; screenshots alone cannot establish this.
- On the actual supported OS, check Increase Contrast, Reduce Transparency and applicable show-borders settings. Do not rely on color alone for status or selection. Follow [Accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility).
- Recheck installed-app layout and interaction on macOS 27. A fake-service preview can validate layout and draft handling, but cannot validate permissions, real playback or audio capture.
