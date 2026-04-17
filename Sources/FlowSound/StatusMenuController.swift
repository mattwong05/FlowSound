import AppKit

@MainActor
final class StatusMenuController {
    private let service: FlowSoundService
    private let activityMonitor: SimulatableAudioActivityMonitor
    private let settingsStore: FlowSoundSettingsStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: 116)
    private let menu = NSMenu()
    private let aboutWindowController = AboutWindowController()
    private let diagnosticsWindowController = StartupWindowController()
    private lazy var preferencesWindowController = PreferencesWindowController(settingsStore: settingsStore)
    private let statusMenuItem = NSMenuItem(title: "Status: Deactivated", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Activate FlowSound", action: #selector(toggleEnabled), keyEquivalent: "")
    private let simulateActiveItem = NSMenuItem(title: "Simulate Watched Audio", action: #selector(simulateActive), keyEquivalent: "")
    private let simulateQuietItem = NSMenuItem(title: "Simulate Quiet", action: #selector(simulateQuiet), keyEquivalent: "")
    private let preferencesMenuItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
    private let aboutMenuItem = NSMenuItem(title: "About FlowSound", action: #selector(showAbout), keyEquivalent: "")
    private let showDiagnosticsMenuItem = NSMenuItem(title: "Show Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "")
    private let diagnosticsMenuItem = NSMenuItem(title: "Copy Diagnostics Path", action: #selector(copyDiagnosticsPath), keyEquivalent: "")

    init(
        service: FlowSoundService,
        activityMonitor: SimulatableAudioActivityMonitor,
        settingsStore: FlowSoundSettingsStore
    ) {
        self.service = service
        self.activityMonitor = activityMonitor
        self.settingsStore = settingsStore
    }

    func install() {
        FlowSoundDiagnostics.log("installing status menu")
        configureStatusButton()
        configureMenu()

        service.onStateChanged = { [weak self] state in
            self?.render(state)
        }
        render(service.state)
        applySettings(settingsStore.settings)
    }

    func applySettings(_ settings: FlowSoundSettings) {
        guard let button = statusItem.button else { return }
        button.title = settings.showsMenuBarText ? "FlowSound" : ""
        button.imagePosition = settings.showsMenuBarText ? .imageLeading : .imageOnly
        statusItem.length = settings.showsMenuBarText ? 116 : 28
        FlowSoundDiagnostics.log("menu bar text visibility: \(settings.showsMenuBarText)")
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            FlowSoundDiagnostics.log("statusItem.button is nil")
            return
        }

        button.title = settingsStore.settings.showsMenuBarText ? "FlowSound" : ""
        button.imagePosition = .imageLeading
        button.toolTip = "FlowSound"

        updateStatusIcon(for: service.state)
    }

    private func configureMenu() {
        toggleMenuItem.target = self
        simulateActiveItem.target = self
        simulateQuietItem.target = self
        preferencesMenuItem.target = self
        aboutMenuItem.target = self
        showDiagnosticsMenuItem.target = self
        diagnosticsMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())
        menu.addItem(simulateActiveItem)
        menu.addItem(simulateQuietItem)
        menu.addItem(.separator())
        menu.addItem(preferencesMenuItem)
        menu.addItem(aboutMenuItem)
        menu.addItem(showDiagnosticsMenuItem)
        menu.addItem(diagnosticsMenuItem)
        menu.addItem(NSMenuItem(title: "Quit FlowSound", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu
        FlowSoundDiagnostics.log("status menu configured with \(menu.items.count) items")
    }

    private func render(_ state: DuckingState) {
        FlowSoundDiagnostics.log("render state: \(state.label)")
        statusMenuItem.title = "Status: \(state.label)"
        toggleMenuItem.title = state == .disabled ? "Activate FlowSound" : "Deactivate FlowSound"
        simulateActiveItem.isEnabled = state != .disabled
        simulateQuietItem.isEnabled = state != .disabled

        if let button = statusItem.button {
            button.toolTip = "FlowSound: \(state.label)"
        }
        updateStatusIcon(for: state)
    }

    @objc private func toggleEnabled() {
        if service.state == .disabled {
            service.enable()
        } else {
            service.disable()
        }
    }

    @objc private func simulateActive() {
        activityMonitor.simulateActive()
    }

    @objc private func simulateQuiet() {
        activityMonitor.simulateQuiet()
    }

    @objc private func showAbout() {
        aboutWindowController.show()
    }

    @objc private func showPreferences() {
        preferencesWindowController.show()
    }

    @objc private func showDiagnostics() {
        diagnosticsWindowController.show()
    }

    @objc private func copyDiagnosticsPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(FlowSoundDiagnostics.logPath, forType: .string)
    }

    @objc private func quit() {
        service.disable()
        NSApp.terminate(nil)
    }

    private func loadBundledImage(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private func updateStatusIcon(for state: DuckingState) {
        let resourceName = state == .disabled ? "FlowSoundMenuBarInactiveTemplate" : "FlowSoundMenuBarActiveTemplate"
        guard let button = statusItem.button else { return }

        if let image = NSImage(named: resourceName) ?? loadBundledImage(named: resourceName) {
            image.isTemplate = true
            image.size = NSSize(width: 22, height: 16)
            button.image = image
            FlowSoundDiagnostics.log("loaded \(resourceName) status image")
        } else if let legacyImage = NSImage(named: "FlowSoundMenuBarTemplate") ?? loadBundledImage(named: "FlowSoundMenuBarTemplate") {
            legacyImage.isTemplate = true
            legacyImage.size = NSSize(width: 22, height: 16)
            button.image = legacyImage
            FlowSoundDiagnostics.log("loaded legacy FlowSoundMenuBarTemplate status image")
        } else if let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "FlowSound") {
            image.isTemplate = true
            button.image = image
            FlowSoundDiagnostics.log("loaded music.note fallback status image")
        } else {
            FlowSoundDiagnostics.log("using text-only status item")
        }
    }
}
