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
        settingsStore.onSettingsChanged = { [weak self, weak flowSoundService, weak controller] settings in
            self?.installMainMenu()
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

    @objc private func showSettings() { statusController?.showPreferences() }

    private func installMainMenu() {
        let text: (String, String) -> String = { FlowSoundLanguage.current == .simplifiedChinese ? $1 : $0 }
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: FlowSoundStrings.text(.menuPreferences), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: FlowSoundStrings.text(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: text("Edit", "编辑"))
        editMenu.addItem(NSMenuItem(title: text("Undo", "撤销"), action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: text("Redo", "重做"), action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: text("Cut", "剪切"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: text("Copy", "复制"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: text("Paste", "粘贴"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: text("Delete", "删除"), action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: text("Select All", "全选"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
