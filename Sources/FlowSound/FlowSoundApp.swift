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
        let musicController = AppleScriptMusicController()
        let activityMonitor = ManualAudioActivityMonitor()
        let flowSoundService = FlowSoundService(
            settings: settings,
            musicController: musicController,
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
            flowSoundService?.updateSettings(settings)
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
