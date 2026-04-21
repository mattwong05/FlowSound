import Foundation
import Testing
@testable import FlowSound

@Test @MainActor func restoreVolumeIsPreservedWhenRestoreIsInterruptedByNewAudio() async throws {
    var settings = FlowSoundSettings.defaults
    settings.quietDuration = 0.05
    settings.fadeOutDuration = 0.1
    settings.fadeInDuration = 0.3

    let musicController = RecordingMusicController(initialVolume: 21)
    let activityMonitor = TestAudioActivityMonitor()
    let service = FlowSoundService(
        settings: settings,
        musicController: musicController,
        activityMonitor: activityMonitor
    )

    service.enable()
    activityMonitor.emit(.active)
    try await Task.sleep(for: .milliseconds(350))
    #expect(service.state == .pausedByFlowSound)

    activityMonitor.emit(.quiet)
    try await Task.sleep(for: .milliseconds(120))
    #expect(service.state == .restoring)

    activityMonitor.emit(.active)
    try await Task.sleep(for: .milliseconds(350))
    #expect(service.state == .pausedByFlowSound)

    activityMonitor.emit(.quiet)
    try await Task.sleep(for: .milliseconds(700))

    let finalVolume = try await musicController.currentVolume()
    #expect(finalVolume == 21)
    #expect(service.state == .listening)
}

private actor RecordingMusicController: MusicController {
    private var volume: Int
    private var state: MusicPlaybackState = .playing

    init(initialVolume: Int) {
        volume = initialVolume
    }

    func currentVolume() async throws -> Int {
        volume
    }

    func playbackState() async throws -> MusicPlaybackState {
        state
    }

    func setVolume(_ volume: Int) async throws {
        self.volume = volume
    }

    func play() async throws {
        state = .playing
    }

    func pause() async throws {
        state = .paused
    }
}

private final class TestAudioActivityMonitor: AudioActivityMonitor {
    var onActivityChanged: (@MainActor (AudioActivity) -> Void)?

    private var isRunning = false

    func start(settings: FlowSoundSettings) throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    @MainActor
    func emit(_ activity: AudioActivity) {
        guard isRunning else { return }
        onActivityChanged?(activity)
    }
}
