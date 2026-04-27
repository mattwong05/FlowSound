import Foundation

@MainActor
final class FlowSoundService {
    typealias StateHandler = @MainActor (DuckingState) -> Void

    var onStateChanged: StateHandler?

    private var settings: FlowSoundSettings
    private var musicAdapter: any MusicControlAdapter
    private let activityMonitor: AudioActivityMonitor
    private var stateMachine = DuckingStateMachine()
    private var currentTask: Task<Void, Never>?
    private var quietTask: Task<Void, Never>?
    private var restoreTarget: MusicRestoreTarget?
    private var pausedByFlowSound = false

    private(set) var state: DuckingState = .disabled {
        didSet {
            onStateChanged?(state)
        }
    }

    init(
        settings: FlowSoundSettings,
        musicAdapter: any MusicControlAdapter,
        activityMonitor: AudioActivityMonitor
    ) {
        self.settings = settings
        self.musicAdapter = musicAdapter
        self.activityMonitor = activityMonitor
        self.activityMonitor.onActivityChanged = { [weak self] activity in
            self?.handle(activity)
        }
    }

    func enable() {
        guard state == .disabled else { return }

        do {
            FlowSoundDiagnostics.log("service enabling")
            try activityMonitor.start(settings: settings)
            transition(.enable)
        } catch {
            FlowSoundDiagnostics.log("service enable failed: \(error.localizedDescription)")
            transition(.failed(error.localizedDescription))
        }
    }

    func disable() {
        FlowSoundDiagnostics.log("service disabling")
        currentTask?.cancel()
        quietTask?.cancel()
        activityMonitor.stop()
        pausedByFlowSound = false
        transition(.disable)
    }

    func updateSettings(_ newSettings: FlowSoundSettings, musicAdapter newMusicAdapter: (any MusicControlAdapter)? = nil) {
        let musicPlayerChanged = newSettings.controlledMusicPlayer != settings.controlledMusicPlayer
        if let newMusicAdapter {
            musicAdapter = newMusicAdapter
        }
        settings = newSettings
        guard state != .disabled else { return }

        do {
            if musicPlayerChanged {
                currentTask?.cancel()
                quietTask?.cancel()
                restoreTarget = nil
                pausedByFlowSound = false
                stateMachine = DuckingStateMachine()
                state = stateMachine.send(.enable)
                FlowSoundDiagnostics.log("service reset ducking state after music app changed to \(musicAdapter.playerName)")
            }
            activityMonitor.stop()
            try activityMonitor.start(settings: newSettings)
            FlowSoundDiagnostics.log("service settings updated while enabled")
        } catch {
            transition(.failed(error.localizedDescription))
        }
    }

    private func handle(_ activity: AudioActivity) {
        FlowSoundDiagnostics.log("service received audio activity: \(activity == .active ? "active" : "quiet") while \(state.label(playerName: musicAdapter.playerName))")
        switch activity {
        case .active:
            quietTask?.cancel()
            guard state == .listening || state == .restoring else { return }
            transition(.watchedAudioStarted)
            startDucking()
        case .quiet:
            guard state == .ducking || state == .pausedByFlowSound else { return }
            scheduleRestoreAfterQuietWindow()
        }
    }

    private func scheduleRestoreAfterQuietWindow() {
        FlowSoundDiagnostics.log("scheduling restore after \(settings.quietDuration) seconds of quiet")
        quietTask?.cancel()
        quietTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(settings.quietDuration))
            guard !Task.isCancelled else { return }
            self.startRestoring()
        }
    }

    private func startDucking() {
        let adapter = musicAdapter
        let playerName = adapter.playerName
        FlowSoundDiagnostics.log("starting \(playerName) ducking")
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            do {
                let target = try await adapter.duck(settings: settings)
                guard let target else {
                    let playbackState = try await adapter.playbackState()
                    FlowSoundDiagnostics.log("\(playerName) is \(playbackState.label); skipping duck and restore")
                    restoreTarget = nil
                    pausedByFlowSound = false
                    transition(.duckSkipped)
                    return
                }
                if let restoreTarget {
                    FlowSoundDiagnostics.log("preserving \(playerName) restore target \(restoreTarget), ignoring in-progress duck target \(target)")
                } else {
                    FlowSoundDiagnostics.log("captured \(playerName) restore target \(target)")
                    restoreTarget = target
                }
                guard !Task.isCancelled else { return }
                pausedByFlowSound = true
                FlowSoundDiagnostics.log("\(playerName) paused by FlowSound")
                transition(.duckCompleted)
            } catch {
                guard !Task.isCancelled else { return }
                FlowSoundDiagnostics.log("\(playerName) ducking failed: \(error.localizedDescription)")
                transition(.failed(error.localizedDescription))
            }
        }
    }

    private func startRestoring() {
        guard pausedByFlowSound || restoreTarget != nil else {
            transition(.restoreCompleted)
            return
        }

        let adapter = musicAdapter
        let playerName = adapter.playerName
        FlowSoundDiagnostics.log("starting \(playerName) restore")
        transition(.watchedAudioStopped)
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            do {
                let target = restoreTarget ?? .absoluteVolume(FlowSoundConstants.defaultRestoreVolume)
                FlowSoundDiagnostics.log("\(playerName) restore target \(target)")
                try await adapter.restore(target, settings: settings)
                guard !Task.isCancelled else { return }
                pausedByFlowSound = false
                restoreTarget = nil
                FlowSoundDiagnostics.log("\(playerName) restore completed")
                transition(.restoreCompleted)
            } catch {
                guard !Task.isCancelled else { return }
                FlowSoundDiagnostics.log("\(playerName) restore failed: \(error.localizedDescription)")
                transition(.failed(error.localizedDescription))
            }
        }
    }

    private func transition(_ event: DuckingEvent) {
        let oldState = state
        state = stateMachine.send(event)
        if oldState != state {
            FlowSoundDiagnostics.log("state transition: \(oldState.label(playerName: musicAdapter.playerName)) -> \(state.label(playerName: musicAdapter.playerName))")
        }
    }
}

enum FlowSoundConstants {
    static let fadeStepDuration: TimeInterval = 0.1
    static let activeCandidateResetDuration: TimeInterval = 0.75
    static let monitorQuietReleaseDuration: TimeInterval = 1.25
    static let defaultRestoreVolume = 50
}

private extension MusicPlaybackState {
    var label: String {
        switch self {
        case .playing:
            "playing"
        case .paused:
            "paused"
        case .stopped:
            "stopped"
        case .unknown(let value):
            value.isEmpty ? "unknown" : "unknown(\(value))"
        }
    }
}
