import Foundation

@MainActor
final class FlowSoundService {
    typealias StateHandler = @MainActor (DuckingState) -> Void

    var onStateChanged: StateHandler?

    private var settings: FlowSoundSettings
    private let musicController: MusicController
    private let activityMonitor: AudioActivityMonitor
    private var stateMachine = DuckingStateMachine()
    private var currentTask: Task<Void, Never>?
    private var quietTask: Task<Void, Never>?
    private var restoreVolume: Int?
    private var pausedByFlowSound = false

    private(set) var state: DuckingState = .disabled {
        didSet {
            onStateChanged?(state)
        }
    }

    init(
        settings: FlowSoundSettings,
        musicController: MusicController,
        activityMonitor: AudioActivityMonitor
    ) {
        self.settings = settings
        self.musicController = musicController
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

    func updateSettings(_ newSettings: FlowSoundSettings) {
        settings = newSettings
        guard state != .disabled else { return }

        do {
            activityMonitor.stop()
            try activityMonitor.start(settings: newSettings)
            FlowSoundDiagnostics.log("service settings updated while enabled")
        } catch {
            transition(.failed(error.localizedDescription))
        }
    }

    private func handle(_ activity: AudioActivity) {
        FlowSoundDiagnostics.log("service received audio activity: \(activity == .active ? "active" : "quiet") while \(state.label)")
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
        FlowSoundDiagnostics.log("starting Apple Music ducking")
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            do {
                let playbackState = try await musicController.playbackState()
                guard playbackState == .playing else {
                    FlowSoundDiagnostics.log("Apple Music is \(playbackState.label); skipping duck and restore")
                    restoreVolume = nil
                    pausedByFlowSound = false
                    transition(.duckSkipped)
                    return
                }
                let currentVolume = try await musicController.currentVolume()
                if let restoreVolume {
                    FlowSoundDiagnostics.log("preserving Apple Music restore volume \(restoreVolume), fading out from \(currentVolume) over \(settings.fadeOutDuration) seconds")
                } else {
                    restoreVolume = currentVolume
                    FlowSoundDiagnostics.log("captured Apple Music volume \(currentVolume), fading out over \(settings.fadeOutDuration) seconds")
                }
                try await fadeVolume(from: currentVolume, to: 0, duration: settings.fadeOutDuration)
                guard !Task.isCancelled else { return }
                try await musicController.pause()
                pausedByFlowSound = true
                FlowSoundDiagnostics.log("Apple Music paused by FlowSound")
                transition(.duckCompleted)
            } catch {
                guard !Task.isCancelled else { return }
                FlowSoundDiagnostics.log("Apple Music ducking failed: \(error.localizedDescription)")
                transition(.failed(error.localizedDescription))
            }
        }
    }

    private func startRestoring() {
        guard pausedByFlowSound || restoreVolume != nil else {
            transition(.restoreCompleted)
            return
        }

        FlowSoundDiagnostics.log("starting Apple Music restore")
        transition(.watchedAudioStopped)
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            do {
                let targetVolume = restoreVolume ?? FlowSoundConstants.defaultRestoreVolume
                if pausedByFlowSound {
                    try await musicController.play()
                    FlowSoundDiagnostics.log("Apple Music play sent, fading in to \(targetVolume) over \(settings.fadeInDuration) seconds")
                    try await fadeVolume(from: 0, to: targetVolume, duration: settings.fadeInDuration)
                } else {
                    let currentVolume = try await musicController.currentVolume()
                    try await fadeVolume(from: currentVolume, to: targetVolume, duration: settings.fadeInDuration)
                }
                guard !Task.isCancelled else { return }
                pausedByFlowSound = false
                restoreVolume = nil
                FlowSoundDiagnostics.log("Apple Music restore completed")
                transition(.restoreCompleted)
            } catch {
                guard !Task.isCancelled else { return }
                FlowSoundDiagnostics.log("Apple Music restore failed: \(error.localizedDescription)")
                transition(.failed(error.localizedDescription))
            }
        }
    }

    private func fadeVolume(from start: Int, to end: Int, duration: TimeInterval) async throws {
        let steps = max(1, Int(duration / FlowSoundConstants.fadeStepDuration))
        for step in 0...steps {
            try Task.checkCancellation()
            let progress = Double(step) / Double(steps)
            let volume = Int(round(Double(start) + (Double(end - start) * progress)))
            try await musicController.setVolume(volume)
            try await Task.sleep(for: .seconds(FlowSoundConstants.fadeStepDuration))
        }
    }

    private func transition(_ event: DuckingEvent) {
        let oldState = state
        state = stateMachine.send(event)
        if oldState != state {
            FlowSoundDiagnostics.log("state transition: \(oldState.label) -> \(state.label)")
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
