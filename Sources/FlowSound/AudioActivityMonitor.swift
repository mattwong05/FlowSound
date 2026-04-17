import Foundation

enum AudioActivity: Sendable, Equatable {
    case active
    case quiet
}

protocol AudioActivityMonitor: AnyObject {
    var onActivityChanged: (@MainActor (AudioActivity) -> Void)? { get set }

    func start(settings: FlowSoundSettings) throws
    func stop()
}

enum AudioActivityMonitorError: LocalizedError {
    case processTapUnavailable

    var errorDescription: String? {
        switch self {
        case .processTapUnavailable:
            "Core Audio process tap monitoring is not wired yet."
        }
    }
}

final class ManualAudioActivityMonitor: AudioActivityMonitor {
    var onActivityChanged: (@MainActor (AudioActivity) -> Void)?

    private(set) var isRunning = false

    func start(settings: FlowSoundSettings) throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
        Task { @MainActor [onActivityChanged] in
            onActivityChanged?(.quiet)
        }
    }

    func simulateActive() {
        guard isRunning else { return }
        Task { @MainActor [onActivityChanged] in
            onActivityChanged?(.active)
        }
    }

    func simulateQuiet() {
        guard isRunning else { return }
        Task { @MainActor [onActivityChanged] in
            onActivityChanged?(.quiet)
        }
    }
}
