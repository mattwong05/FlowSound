import AppKit

@MainActor
final class FlowSoundApp: NSObject, NSApplicationDelegate {
    private var statusController: StatusMenuController?
    private var service: FlowSoundService?
    private let settingsStore = FlowSoundSettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        FlowSoundDiagnostics.log("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()

        let settings = settingsStore.settings
        let musicAdapter = MusicControlAdapterFactory.adapter(for: settings.controlledMusicPlayer)
        let activityMonitor = CoreAudioProcessTapMonitor()
        let flowSoundService = FlowSoundService(
            settings: settings,
            musicAdapter: musicAdapter,
            activityMonitor: activityMonitor
        )

        let controller = StatusMenuController(
            service: flowSoundService,
            activityMonitor: activityMonitor,
            settingsStore: settingsStore
        )
        self.service = flowSoundService
        self.statusController = controller
        settingsStore.onSettingsChanged = { [weak flowSoundService, weak controller] settings in
            flowSoundService?.updateSettings(
                settings,
                musicAdapter: MusicControlAdapterFactory.adapter(for: settings.controlledMusicPlayer)
            )
            controller?.applySettings(settings)
        }
        controller.install()
        flowSoundService.enable()
        FlowSoundDiagnostics.log("service activated by default on launch")
        FlowSoundDiagnostics.log("status controller installed")
    }

    func applicationWillTerminate(_ notification: Notification) {
        service?.disable()
        FlowSoundDiagnostics.log("applicationWillTerminate")
        FlowSoundDiagnostics.flush()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: FlowSoundStrings.text(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
