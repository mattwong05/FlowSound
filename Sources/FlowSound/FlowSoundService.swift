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
            try activityMonitor.start(settings: settings)
            transition(.enable)
        } catch {
            transition(.failed(error.localizedDescription))
        }
    }

    func disable() {
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
        quietTask?.cancel()
        quietTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(settings.quietDuration))
            guard !Task.isCancelled else { return }
            self.startRestoring()
        }
    }

    private func startDucking() {
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            do {
                let originalVolume = try await musicController.currentVolume()
                restoreVolume = originalVolume
                try await fadeVolume(from: originalVolume, to: 0, duration: settings.fadeOutDuration)
                guard !Task.isCancelled else { return }
                try await musicController.pause()
                pausedByFlowSound = true
                transition(.duckCompleted)
            } catch {
                guard !Task.isCancelled else { return }
                transition(.failed(error.localizedDescription))
            }
        }
    }

    private func startRestoring() {
        guard pausedByFlowSound || restoreVolume != nil else {
            transition(.restoreCompleted)
            return
        }

        transition(.watchedAudioStopped)
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            do {
                let targetVolume = restoreVolume ?? FlowSoundConstants.defaultRestoreVolume
                if pausedByFlowSound {
                    try await musicController.play()
                    try await fadeVolume(from: 0, to: targetVolume, duration: settings.fadeInDuration)
                } else {
                    let currentVolume = try await musicController.currentVolume()
                    try await fadeVolume(from: currentVolume, to: targetVolume, duration: settings.fadeInDuration)
                }
                guard !Task.isCancelled else { return }
                pausedByFlowSound = false
                restoreVolume = nil
                transition(.restoreCompleted)
            } catch {
                guard !Task.isCancelled else { return }
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
        state = stateMachine.send(event)
    }
}

enum FlowSoundConstants {
    static let fadeStepDuration: TimeInterval = 0.1
    static let monitorQuietReleaseDuration: TimeInterval = 0.25
    static let defaultRestoreVolume = 50
}
