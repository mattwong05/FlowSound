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
    private var monitorTask: Task<Void, Never>?
    private var generation = UUID()
    private var monitorGeneration = UUID()
    private var quietSince: ContinuousClock.Instant?
    private var restoreSession: RestoreSession?

    private struct RestoreSession {
        let player: ControlledMusicPlayer
        let instance: Int32?
        let target: MusicRestoreTarget
    }

    private(set) var monitorStatus: AudioMonitorStatus = .stopped {
        didSet { if oldValue != monitorStatus { onStateChanged?(state) } }
    }
    private(set) var restoreDeadline: Date?
    private(set) var lastActivity: AudioActivity = .quiet
    private(set) var lastControlError: String?
    private(set) var lastControlSucceededAt: Date?
    private(set) var state: DuckingState = .disabled {
        didSet { onStateChanged?(state) }
    }

    init(settings: FlowSoundSettings, musicAdapter: any MusicControlAdapter, activityMonitor: AudioActivityMonitor) {
        self.settings = settings
        self.musicAdapter = musicAdapter
        self.activityMonitor = activityMonitor
        activityMonitor.onActivityChanged = { [weak self] in self?.handle($0) }
        activityMonitor.onStatusChanged = { [weak self] in self?.monitorStatusChanged($0) }
    }

    func enable() {
        guard state == .disabled else { return }
        transition(.enable)
        startMonitoring()
    }

    func retry() {
        guard case .error = state else { return }
        cancelControl()
        lastControlError = nil
        transition(.enable)
        startMonitoring()
    }

    func disable() {
        cancelControl()
        monitorGeneration = UUID()
        monitorTask?.cancel()
        activityMonitor.stop()
        monitorStatus = .stopped
        restoreSession = nil
        lastActivity = .quiet
        transition(.disable)
    }

    func updateSettings(_ newSettings: FlowSoundSettings, musicAdapter newMusicAdapter: (any MusicControlAdapter)? = nil) {
        let oldSettings = settings
        let playerChanged = newSettings.controlledMusicPlayer != oldSettings.controlledMusicPlayer
        settings = newSettings
        if playerChanged {
            cancelControl()
            restoreSession = nil
            lastControlError = nil
            lastControlSucceededAt = nil
            if let newMusicAdapter { musicAdapter = newMusicAdapter }
        }
        guard state != .disabled else { return }
        if playerChanged {
            stateMachine = DuckingStateMachine()
            transition(.enable)
        }
        if newSettings.requiresMonitorRestart(comparedTo: oldSettings) {
            startMonitoring()
        } else if newSettings.quietDuration != oldSettings.quietDuration, quietSince != nil {
            scheduleRestore()
        }
    }

    private func startMonitoring() {
        let token = UUID()
        monitorGeneration = token
        monitorTask?.cancel()
        cancelQuietWindow()
        suspendRestoreForMonitorChange()
        monitorStatus = .starting
        activityMonitor.stop()
        let monitorSettings = settings
        monitorTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await activityMonitor.start(settings: monitorSettings)
                guard !Task.isCancelled, monitorGeneration == token, state != .disabled else { return }
                monitorStatus = .running
                if state == .starting { transition(restoreSession == nil ? .monitorReady : .resumePaused) }
                // The monitor supplies an initial activity only after observing the new stream.
            } catch {
                guard !Task.isCancelled, monitorGeneration == token, state != .disabled else { return }
                monitorStatusChanged(.failed(error.localizedDescription))
            }
        }
    }

    private func monitorStatusChanged(_ status: AudioMonitorStatus) {
        guard state != .disabled else { return }
        monitorStatus = status
        switch status {
        case .starting, .recovering, .stopped:
            cancelQuietWindow()
            suspendRestoreForMonitorChange()
        case .running:
            if state == .starting { transition(restoreSession == nil ? .monitorReady : .resumePaused) }
        case .failed(let message):
            cancelControl()
            transition(.failed(message))
        }
    }

    private func handle(_ activity: AudioActivity) {
        guard state != .disabled, monitorStatus == .running else { return }
        lastActivity = activity
        switch activity {
        case .active:
            cancelQuietWindow()
            guard state == .listening || state == .restoring else { return }
            transition(.watchedAudioStarted)
            startDucking()
        case .quiet:
            if quietSince == nil { quietSince = .now }
            guard state == .ducking || state == .pausedByFlowSound else { return }
            scheduleRestore()
        }
    }

    private func suspendRestoreForMonitorChange() {
        guard state == .restoring else { return }
        // Cancel before any further play/fade commands. If playback had begun, duck
        // again; if it was still paused, the existing ownership is retained.
        transition(.watchedAudioStarted)
        startDucking()
    }

    private func cancelQuietWindow() {
        quietTask?.cancel()
        quietTask = nil
        quietSince = nil
        restoreDeadline = nil
    }

    private func cancelControl() {
        generation = UUID()
        currentTask?.cancel()
        currentTask = nil
        cancelQuietWindow()
    }

    private func scheduleRestore() {
        guard let quietSince, lastActivity == .quiet, monitorStatus == .running else { return }
        quietTask?.cancel()
        let deadline = quietSince.advanced(by: .seconds(settings.quietDuration))
        let remaining = max(0, ContinuousClock.now.duration(to: deadline).secondsValue)
        restoreDeadline = Date().addingTimeInterval(remaining)
        let token = generation
        quietTask = Task { [weak self] in
            do { try await ContinuousClock().sleep(until: deadline) } catch { return }
            guard let self, !Task.isCancelled, generation == token,
                  lastActivity == .quiet, monitorStatus == .running else { return }
            // A pending duck owns its completion. It rechecks this same deadline below.
            guard state == .pausedByFlowSound else { return }
            startRestoring()
        }
    }

    private func startDucking() {
        currentTask?.cancel()
        let token = UUID()
        generation = token
        let adapter = musicAdapter
        let player = settings.controlledMusicPlayer
        let operationSettings = settings
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let instance = await adapter.instanceIdentifier()
                guard isCurrent(token) else { return }
                let target = try await adapter.duck(settings: operationSettings)
                guard isCurrent(token) else { return }
                guard let target else {
                    if let session = restoreSession, session.player == player, session.instance == instance {
                        let stillOwned = try await adapter.mayRestore(session.target)
                        guard isCurrent(token) else { return }
                        if stillOwned {
                            transition(.duckCompleted)
                            if lastActivity == .quiet { scheduleRestore() }
                            return
                        }
                    }
                    restoreSession = nil
                    transition(.duckSkipped)
                    return
                }
                let isRelative: Bool
                if case .relativeSteps = target { isRelative = true } else { isRelative = false }
                if isRelative || restoreSession?.player != player || restoreSession?.instance != instance {
                    restoreSession = RestoreSession(player: player, instance: instance, target: target)
                }
                lastControlError = nil
                lastControlSucceededAt = Date()
                transition(.duckCompleted)
                // Quiet can arrive and expire while duck() is still awaiting a command.
                if lastActivity == .quiet { scheduleRestore() }
            } catch {
                guard isCurrent(token) else { return }
                controlFailed(error)
            }
        }
    }

    private func startRestoring() {
        guard let session = restoreSession, session.player == settings.controlledMusicPlayer else { return }
        restoreDeadline = nil
        currentTask?.cancel()
        let token = UUID()
        generation = token
        let adapter = musicAdapter
        let operationSettings = settings
        transition(.watchedAudioStopped)
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let instance = await adapter.instanceIdentifier()
                guard isCurrent(token) else { return }
                let mayRestore = instance == session.instance ? try await adapter.mayRestore(session.target) : false
                guard isCurrent(token) else { return }
                guard mayRestore else {
                    relinquishControl()
                    return
                }
                try await adapter.restore(session.target, settings: operationSettings)
                guard isCurrent(token) else { return }
                restoreSession = nil
                lastControlError = nil
                lastControlSucceededAt = Date()
                transition(.restoreCompleted)
            } catch {
                guard isCurrent(token) else { return }
                controlFailed(error)
            }
        }
    }

    private func isCurrent(_ token: UUID) -> Bool {
        !Task.isCancelled && generation == token && state != .disabled
    }

    private func relinquishControl() {
        restoreSession = nil
        lastControlError = FlowSoundLanguage.current == .simplifiedChinese
            ? "播放器状态或音量已改变，已放弃自动恢复。"
            : "Player state or volume changed; automatic restore was relinquished."
        transition(.controlRelinquished)
    }

    private func controlFailed(_ error: Error) {
        cancelQuietWindow()
        if case MusicControlAdapterError.userIntervened = error {
            relinquishControl()
        } else {
            lastControlError = error.localizedDescription
            FlowSoundDiagnostics.log("Music control failed: \(error.localizedDescription)")
            transition(.failed(error.localizedDescription))
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

private extension Duration {
    var secondsValue: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}

enum FlowSoundConstants {
    static let fadeStepDuration: TimeInterval = 0.1
    static let activeCandidateResetDuration: TimeInterval = 0.75
    static let monitorQuietReleaseDuration: TimeInterval = 1.25
    static let defaultRestoreVolume = 50
}
