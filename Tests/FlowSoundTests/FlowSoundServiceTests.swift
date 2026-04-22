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
    try await waitForState(.pausedByFlowSound, in: service)

    activityMonitor.emit(.quiet)
    try await waitForState(.restoring, in: service)

    activityMonitor.emit(.active)
    try await waitForState(.pausedByFlowSound, in: service)

    activityMonitor.emit(.quiet)
    try await waitForState(.listening, in: service, timeout: .seconds(3))

    let finalVolume = try await musicController.currentVolume()
    #expect(finalVolume == 21)
    #expect(service.state == .listening)
}

@Test @MainActor func changingMusicPlayerClearsPendingRestoreState() async throws {
    var settings = FlowSoundSettings.defaults
    settings.quietDuration = 0.05
    settings.fadeOutDuration = 0.1
    settings.fadeInDuration = 0.1

    let appleMusicController = RecordingMusicController(playerName: "Apple Music", initialVolume: 21)
    let spotifyController = RecordingMusicController(playerName: "Spotify", initialVolume: 70)
    let activityMonitor = TestAudioActivityMonitor()
    let service = FlowSoundService(
        settings: settings,
        musicController: appleMusicController,
        activityMonitor: activityMonitor
    )

    service.enable()
    activityMonitor.emit(.active)
    try await waitForState(.pausedByFlowSound, in: service)

    settings.controlledMusicPlayer = .spotify
    service.updateSettings(settings, musicController: spotifyController)
    activityMonitor.emit(.quiet)
    try await Task.sleep(for: .milliseconds(150))

    #expect(service.state == .listening)
    #expect(try await spotifyController.currentVolume() == 70)
}

@MainActor
private func waitForState(
    _ expectedState: DuckingState,
    in service: FlowSoundService,
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(25),
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let deadline = ContinuousClock.now + timeout
    while service.state != expectedState, ContinuousClock.now < deadline {
        try await Task.sleep(for: pollInterval)
    }
    #expect(service.state == expectedState, sourceLocation: sourceLocation)
}

private actor RecordingMusicController: MusicController {
    nonisolated let playerName: String
    private var volume: Int
    private var state: MusicPlaybackState = .playing

    init(playerName: String = "Test Music", initialVolume: Int) {
        self.playerName = playerName
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
