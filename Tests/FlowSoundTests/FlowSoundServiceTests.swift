import Foundation
import Testing
@testable import FlowSound

@Test func appleScriptMusicAdaptersDeclareOfficialAbsoluteVolumeCapabilities() {
    let appleMusicAdapter = AppleScriptMusicControlAdapter(player: .appleMusic)
    let spotifyAdapter = AppleScriptMusicControlAdapter(player: .spotify)

    #expect(appleMusicAdapter.descriptor.supportLevel == .official)
    #expect(appleMusicAdapter.descriptor.capabilities.playbackState == .native)
    #expect(appleMusicAdapter.descriptor.capabilities.volumeControl == .absolute)
    #expect(appleMusicAdapter.descriptor.bundleIdentifiers == ["com.apple.Music", "com.apple.iTunes"])

    #expect(spotifyAdapter.descriptor.supportLevel == .official)
    #expect(spotifyAdapter.descriptor.capabilities.playbackState == .native)
    #expect(spotifyAdapter.descriptor.capabilities.volumeControl == .absolute)
    #expect(spotifyAdapter.descriptor.bundleIdentifiers == ["com.spotify.client"])
}

@Test func neteaseAdapterDeclaresExperimentalRelativeStepCapabilities() {
    let adapter = NeteaseCloudMusicControlAdapter()

    #expect(adapter.descriptor.supportLevel == .experimental)
    #expect(adapter.descriptor.displayName == "Netease Cloud Music")
    #expect(adapter.descriptor.capabilities.playbackState == .menuState)
    #expect(adapter.descriptor.capabilities.volumeControl == .relativeStep)
    #expect(adapter.descriptor.bundleIdentifiers == ["com.netease.163music"])
}

@Test func neteaseRestoreUsesConservativeRelativeStepCount() {
    #expect(NeteaseCloudMusicControlAdapter.restoreStepCount(forFadeOutSteps: 1) == 1)
    #expect(NeteaseCloudMusicControlAdapter.restoreStepCount(forFadeOutSteps: 2) == 2)
    #expect(NeteaseCloudMusicControlAdapter.restoreStepCount(forFadeOutSteps: 12) == 10)
}

@Test @MainActor func restoreVolumeIsPreservedWhenRestoreIsInterruptedByNewAudio() async throws {
    var settings = FlowSoundSettings.defaults
    settings.quietDuration = 0.05
    settings.fadeOutDuration = 0.1
    settings.fadeInDuration = 0.3

    let musicAdapter = RecordingMusicAdapter(initialVolume: 21)
    let activityMonitor = TestAudioActivityMonitor()
    let service = FlowSoundService(
        settings: settings,
        musicAdapter: musicAdapter,
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

    let finalVolume = try await musicAdapter.currentVolume()
    #expect(finalVolume == 21)
    #expect(service.state == .listening)
}

@Test @MainActor func changingMusicPlayerClearsPendingRestoreState() async throws {
    var settings = FlowSoundSettings.defaults
    settings.quietDuration = 0.05
    settings.fadeOutDuration = 0.1
    settings.fadeInDuration = 0.1

    let appleMusicAdapter = RecordingMusicAdapter(playerName: "Apple Music", initialVolume: 21)
    let spotifyAdapter = RecordingMusicAdapter(playerName: "Spotify", initialVolume: 70)
    let activityMonitor = TestAudioActivityMonitor()
    let service = FlowSoundService(
        settings: settings,
        musicAdapter: appleMusicAdapter,
        activityMonitor: activityMonitor
    )

    service.enable()
    activityMonitor.emit(.active)
    try await waitForState(.pausedByFlowSound, in: service)

    settings.controlledMusicPlayer = .spotify
    service.updateSettings(settings, musicAdapter: spotifyAdapter)
    activityMonitor.emit(.quiet)
    try await Task.sleep(for: .milliseconds(150))

    #expect(service.state == .listening)
    #expect(try await spotifyAdapter.currentVolume() == 70)
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

private actor RecordingMusicAdapter: AbsoluteVolumeMusicControlAdapter {
    nonisolated let playerName: String
    nonisolated let descriptor: MusicControlAdapterDescriptor
    private var volume: Int
    private var state: MusicPlaybackState = .playing

    init(playerName: String = "Test Music", initialVolume: Int) {
        self.playerName = playerName
        descriptor = MusicControlAdapterDescriptor(
            id: "test.\(playerName.lowercased().replacingOccurrences(of: " ", with: "-"))",
            displayName: playerName,
            supportLevel: .official,
            bundleIdentifiers: ["test.\(playerName.lowercased().replacingOccurrences(of: " ", with: "-"))"],
            capabilities: MusicAdapterCapabilities(
                playbackState: .native,
                volumeControl: .absolute
            )
        )
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

    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget? {
        guard state == .playing else {
            return nil
        }
        let target = MusicRestoreTarget.absoluteVolume(volume)
        volume = 0
        state = .paused
        return target
    }

    func restore(_ target: MusicRestoreTarget, settings: FlowSoundSettings) async throws {
        guard case .absoluteVolume(let volume) = target else {
            return
        }
        state = .playing
        try await Task.sleep(for: .seconds(settings.fadeInDuration))
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
