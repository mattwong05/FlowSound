import Foundation

enum DuckingState: Sendable, Equatable {
    case disabled
    case listening
    case ducking
    case pausedByFlowSound
    case restoring
    case error(String)

    var label: String {
        switch self {
        case .disabled:
            "Deactivated"
        case .listening:
            "Activated"
        case .ducking:
            "Ducking Apple Music"
        case .pausedByFlowSound:
            "Apple Music paused"
        case .restoring:
            "Restoring Apple Music"
        case .error(let message):
            "Error: \(message)"
        }
    }
}

enum DuckingEvent: Sendable, Equatable {
    case enable
    case disable
    case watchedAudioStarted
    case watchedAudioStopped
    case duckSkipped
    case duckCompleted
    case restoreCompleted
    case failed(String)
}

struct DuckingStateMachine: Sendable {
    private(set) var state: DuckingState = .disabled

    mutating func send(_ event: DuckingEvent) -> DuckingState {
        switch (state, event) {
        case (_, .disable):
            state = .disabled
        case (.disabled, .enable):
            state = .listening
        case (.listening, .watchedAudioStarted):
            state = .ducking
        case (.ducking, .watchedAudioStopped):
            state = .restoring
        case (.ducking, .duckSkipped):
            state = .listening
        case (.ducking, .duckCompleted):
            state = .pausedByFlowSound
        case (.pausedByFlowSound, .watchedAudioStopped):
            state = .restoring
        case (.restoring, .watchedAudioStarted):
            state = .ducking
        case (.restoring, .restoreCompleted):
            state = .listening
        case (_, .failed(let message)):
            state = .error(message)
        case (.error, .enable):
            state = .listening
        default:
            break
        }

        return state
    }
}
