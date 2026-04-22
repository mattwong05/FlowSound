import AppKit

@MainActor
final class StatusMenuController {
    private let service: FlowSoundService
    private let activityMonitor: SimulatableAudioActivityMonitor
    private let settingsStore: FlowSoundSettingsStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private let menu = NSMenu()
    private let aboutWindowController = AboutWindowController()
    private let diagnosticsWindowController = StartupWindowController()
    private lazy var preferencesWindowController = PreferencesWindowController(settingsStore: settingsStore)
    private let statusMenuItem = NSMenuItem(title: FlowSoundStrings.text(.status(FlowSoundStrings.text(.deactivated))), action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: FlowSoundStrings.text(.menuActivate), action: #selector(toggleEnabled), keyEquivalent: "")
    private let simulateActiveItem = NSMenuItem(title: FlowSoundStrings.text(.menuSimulateActive), action: #selector(simulateActive), keyEquivalent: "")
    private let simulateQuietItem = NSMenuItem(title: FlowSoundStrings.text(.menuSimulateQuiet), action: #selector(simulateQuiet), keyEquivalent: "")
    private let preferencesMenuItem = NSMenuItem(title: FlowSoundStrings.text(.menuPreferences), action: #selector(showPreferences), keyEquivalent: ",")
    private let aboutMenuItem = NSMenuItem(title: FlowSoundStrings.text(.menuAbout), action: #selector(showAbout), keyEquivalent: "")

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
        button.title = ""
        button.imagePosition = .imageOnly
        statusItem.length = 28
        FlowSoundDiagnostics.log("menu bar text visibility: false")
        refreshMenuTitles()
        render(service.state)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            FlowSoundDiagnostics.log("statusItem.button is nil")
            return
        }

        button.title = ""
        button.imagePosition = .imageOnly
        button.toolTip = "FlowSound"

        updateStatusIcon(for: service.state)
    }

    private func configureMenu() {
        toggleMenuItem.target = self
        simulateActiveItem.target = self
        simulateQuietItem.target = self
        preferencesMenuItem.target = self
        aboutMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())
        menu.addItem(simulateActiveItem)
        menu.addItem(simulateQuietItem)
        menu.addItem(.separator())
        menu.addItem(preferencesMenuItem)
        menu.addItem(aboutMenuItem)
        menu.addItem(NSMenuItem(title: FlowSoundStrings.text(.menuQuit), action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu
        FlowSoundDiagnostics.log("status menu configured with \(menu.items.count) items")
    }

    private func render(_ state: DuckingState) {
        let label = state.label(playerName: settingsStore.settings.controlledMusicPlayer.displayName)
        FlowSoundDiagnostics.log("render state: \(label)")
        statusMenuItem.title = FlowSoundStrings.text(.status(label))
        toggleMenuItem.title = state == .disabled ? FlowSoundStrings.text(.menuActivate) : FlowSoundStrings.text(.menuDeactivate)
        simulateActiveItem.isEnabled = state != .disabled
        simulateQuietItem.isEnabled = state != .disabled

        if let button = statusItem.button {
            button.toolTip = "FlowSound: \(label)"
        }
        updateStatusIcon(for: state)
    }

    private func refreshMenuTitles() {
        preferencesMenuItem.title = FlowSoundStrings.text(.menuPreferences)
        aboutMenuItem.title = FlowSoundStrings.text(.menuAbout)
        simulateActiveItem.title = FlowSoundStrings.text(.menuSimulateActive)
        simulateQuietItem.title = FlowSoundStrings.text(.menuSimulateQuiet)
        menu.items.last?.title = FlowSoundStrings.text(.menuQuit)
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

    func showDiagnostics() {
        diagnosticsWindowController.show()
    }

    func copyDiagnosticsPath() {
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
