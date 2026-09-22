// Native UI regression harness: isolated preferences, fake music adapter, no audio capture.
// Run through scripts/preview-ui.sh, never as the production app entry point.
import AppKit
import Foundation

private struct PreviewMusicAdapter: MusicControlAdapter {
    let playerName = "Preview Player"
    let descriptor = MusicControlAdapterDescriptor(id: "preview", displayName: "Preview Player", supportLevel: .experimental, bundleIdentifiers: ["org.example.preview"], capabilities: MusicAdapterCapabilities(playbackState: .native, volumeControl: .absolute))
    func playbackState() async throws -> MusicPlaybackState { .paused }
    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget? { .absoluteVolume(60) }
    func restore(_ target: MusicRestoreTarget, settings: FlowSoundSettings) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func instanceIdentifier() async -> Int32? { 12345 }
}

@main @MainActor private struct Preview {
    static let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/ui-preview")
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        for theme in ["light", "dark"] {
            app.appearance = NSAppearance(named: theme == "light" ? .aqua : .darkAqua)
            for language in [FlowSoundLanguagePreference.english, .simplifiedChinese] {
                UserDefaults.standard.setVolatileDomain([FlowSoundLanguagePreference.defaultsKey: language.rawValue], forName: UserDefaults.argumentDomain)
                let suite = "FlowSound.DesignPreview.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                let store = FlowSoundSettingsStore(defaults: defaults)
                let monitor = ManualAudioActivityMonitor()
                let service = FlowSoundService(settings: store.settings, musicAdapter: PreviewMusicAdapter(), activityMonitor: monitor)
                let preferences = PreferencesWindowController(settingsStore: store, service: service, activityMonitor: monitor)
                RecentAudioSourceStore.shared.record(bundleIdentifier: "com.example.Video", pid: -1, status: .detected)
                RecentAudioSourceStore.shared.record(bundleIdentifier: "com.apple.Safari", pid: -1, status: .watched)
                var writes = 0
                store.onSettingsChanged = { _ in writes += 1 }
                preferences.show()
                app.activate(ignoringOtherApps: true)
                pump()
                let window = NSApp.windows.first { $0.identifier?.rawValue == "FlowSound.Settings" && $0.isVisible }!
                let prefix = "\(language.rawValue)-\(theme)"
                for (index,name) in ["general","applications","sound","tools"].enumerated() {
                    select(window, index)
                    try snapshot(window, "\(prefix)-\(name)")
                }
                let profilesTitle = language == .english ? "Community adapters" : "社区适配器"
                let profiles = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.title == profilesTitle }!
                profiles.performClick(nil); pump()
                let toolsPage = allViews(window.contentView!).compactMap { $0 as? NSScrollView }.first { !$0.isHiddenOrHasHiddenAncestor }!
                toolsPage.contentView.scroll(to: NSPoint(x: 0, y: max(0, toolsPage.documentView!.frame.height - toolsPage.contentSize.height)))
                toolsPage.reflectScrolledClipView(toolsPage.contentView)
                try snapshot(window, "\(prefix)-community")
                profiles.performClick(nil); pump()
                select(window, 0)
                let player = allViews(window.contentView!).compactMap { $0 as? NSPopUpButton }.first { $0.itemArray.contains(where: { ($0.representedObject as? String) == ControlledMusicPlayer.neteaseCloudMusic.rawValue }) }!
                player.selectItem(at: ControlledMusicPlayer.allCases.firstIndex(of: .neteaseCloudMusic)!)
                NSApp.sendAction(player.action!, to: player.target, from: player); pump()
                precondition(writes == 0, "Player selection saved before Save")
                if theme == "dark" { try snapshot(window, "\(prefix)-experimental") }
                player.selectItem(at: 0)
                NSApp.sendAction(player.action!, to: player.target, from: player); pump()
                select(window, 2)
                let slider = allViews(window.contentView!).compactMap { $0 as? NSSlider }.first!
                slider.doubleValue = 3.7
                NSApp.sendAction(slider.action!, to: slider.target, from: slider); pump()
                precondition(writes == 0, "Slider saved before Save")
                select(window, 1)
                let original = store.settings
                let remove = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityIdentifier().contains("watchedRules.remove.") == true }!
                remove.performClick(nil)
                pump()
                precondition(writes == 0, "Removal saved before Save")
                click("settings.cancel", window)
                preferences.show(); pump()
                precondition(store.settings == original, "Cancel changed persisted settings")
                select(window, 1)
                while let button = allViews(window.contentView!).compactMap({ $0 as? NSButton }).first(where: { $0.accessibilityIdentifier().contains("watchedRules.remove.") == true }) {
                    button.performClick(nil); pump()
                }
                try snapshot(window, "\(prefix)-empty")
                let advancedTitle = language == .english ? "Advanced rules" : "高级规则"
                let disclosure = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.title == advancedTitle }!
                disclosure.performClick(nil); pump()
                let page = allViews(window.contentView!).compactMap { $0 as? NSScrollView }.first { !$0.isHiddenOrHasHiddenAncestor }!
                page.contentView.scroll(to: NSPoint(x: 0, y: max(0, page.documentView!.frame.height - page.contentSize.height)))
                page.reflectScrolledClipView(page.contentView)
                try snapshot(window, "\(prefix)-advanced-rules")
                precondition(writes == 0)
                click("settings.save", window)
                precondition(writes == 1 && store.settings.watchedBundleIdentifiers.isEmpty, "Save did not persist empty rules")
                select(window, 2)
                let savedSlider = allViews(window.contentView!).compactMap { $0 as? NSSlider }.first!
                savedSlider.doubleValue = 3.7
                NSApp.sendAction(savedSlider.action!, to: savedSlider.target, from: savedSlider); pump()
                click("settings.save", window)
                precondition(writes == 2 && store.settings.fadeOutDuration == 3.7, "Slider Save did not persist exact value")
                click("settings.reset", window)
                precondition(writes == 2, "Reset saved immediately")
                click("settings.cancel", window)
                precondition(store.settings.watchedBundleIdentifiers.isEmpty && store.settings.fadeOutDuration == 3.7, "Cancel after Reset changed saved values")
                if theme == "light" && language == .english {
                    preferences.show(); pump(); select(window, 1)
                    let editors = allViews(window.contentView!).compactMap { $0 as? NSTextView }
                    let watched = editors.first { $0.accessibilityLabel() == "Watched apps" }!
                    watched.string = (0..<18).map { "com.example.AVeryLongApplicationIdentifierForLayoutChecks\($0)" }.joined(separator: "\n")
                    watched.didChangeText(); pump()
                    let excluded = editors.first { $0.accessibilityLabel() == "Ignored apps" }!
                    excluded.string += "\ncom.example.AVeryLongApplicationIdentifierForLayoutChecks0"
                    excluded.didChangeText(); pump()
                    let focusedRemove = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.accessibilityIdentifier() == "watchedRules.remove.com.example.AVeryLongApplicationIdentifierForLayoutChecks0" }!
                    precondition(window.makeFirstResponder(focusedRemove))
                    watched.didChangeText(); pump()
                    precondition((window.firstResponder as? NSButton)?.accessibilityIdentifier().hasPrefix("watchedRules.remove.") == true, "Refreshing overlapping rules moved focus to the other column")
                    window.makeFirstResponder(nil)
                    let toggle = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.title == "Advanced rules" }!
                    if toggle.state == .on { toggle.performClick(nil); pump() }
                    let page = allViews(window.contentView!).compactMap { $0 as? NSScrollView }.first { !$0.isHiddenOrHasHiddenAncestor }!
                    page.contentView.scroll(to: .zero); page.reflectScrolledClipView(page.contentView)
                    try snapshot(window, "english-light-long-list")
                    window.setContentSize(NSSize(width: 820, height: 420)); pump()
                    let save = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "settings.save" }!
                    precondition(window.contentView!.bounds.contains(save.convert(save.bounds, to: window.contentView)), "Save is clipped on short windows")
                    try snapshot(window, "english-light-short-window")
                    click("settings.cancel", window)
                    precondition(writes == 2)
                }
                let diagnostics = StartupWindowController(service: service, activityMonitor: monitor, settingsStore: store)
                diagnostics.show(); pump()
                let diagnosticWindow = NSApp.windows.first { $0.title == FlowSoundStrings.text(.diagnosticsTitle) && $0.isVisible }!
                try snapshot(diagnosticWindow, "\(prefix)-diagnostics")
                let advanced = allViews(diagnosticWindow.contentView!).compactMap { $0 as? NSButton }.first { $0.title == FlowSoundStrings.text(.advancedDiagnostics) }!
                advanced.performClick(nil); pump()
                let diagScroll = diagnosticWindow.contentView as! NSScrollView
                diagScroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, diagScroll.documentView!.frame.height - diagScroll.contentSize.height)))
                diagScroll.reflectScrolledClipView(diagScroll.contentView)
                try snapshot(diagnosticWindow, "\(prefix)-diagnostics-advanced")
                diagnosticWindow.close()
                let about = AboutWindowController()
                about.show(); pump()
                let aboutWindow = NSApp.windows.first { $0.title == FlowSoundStrings.text(.aboutTitle) && $0.isVisible }!
                try snapshot(aboutWindow, "\(prefix)-about")
                aboutWindow.close()
                print("PASS \(prefix): removal, empty Save, precise slider Save, Reset, Cancel")
                withExtendedLifetime((preferences, diagnostics, about)) {}
            }
        }
        print("Screenshots: \(output.path)")
        try "PASS".write(to: output.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
    }
    static func pump() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
        NSApp.windows.forEach { $0.contentView?.layoutSubtreeIfNeeded(); $0.displayIfNeeded() }
    }
    static func allViews(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(allViews) }
    static func select(_ window: NSWindow, _ index: Int) {
        let item = window.toolbar!.items.first { $0.tag == index }!
        NSApp.sendAction(item.action!, to: item.target, from: item)
        pump()
    }
    static func click(_ id: String, _ window: NSWindow) {
        let button = allViews(window.contentView!).compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == id }!
        button.performClick(nil); pump()
    }
    static func snapshot(_ window: NSWindow, _ name: String) throws {
        pump()
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), output.appendingPathComponent(name+".png").path]
        try capture.run(); capture.waitUntilExit()
        precondition(capture.terminationStatus == 0)
    }
}
