import AppKit

@MainActor
final class FlowSoundApp: NSObject, NSApplicationDelegate {
    private var statusController: StatusMenuController?
    private var service: FlowSoundService?
    private let settingsStore = FlowSoundSettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        FlowSoundDiagnostics.log("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)

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
        FlowSoundDiagnostics.log("applicationWillTerminate")
    }
}
