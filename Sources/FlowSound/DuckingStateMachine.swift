import Foundation

enum DuckingState: Sendable, Equatable {
    case disabled
    case starting
    case listening
    case ducking
    case pausedByFlowSound
    case restoring
    case error(String)

    var label: String {
        label(playerName: ControlledMusicPlayer.appleMusic.displayName)
    }

    func label(playerName: String) -> String {
        switch self {
        case .disabled:
            FlowSoundStrings.text(.deactivated)
        case .starting:
            FlowSoundStrings.text(.starting)
        case .listening:
            FlowSoundStrings.text(.activated)
        case .ducking:
            FlowSoundStrings.text(.ducking(playerName))
        case .pausedByFlowSound:
            FlowSoundStrings.text(.pausedByFlowSound(playerName))
        case .restoring:
            FlowSoundStrings.text(.restoring(playerName))
        case .error(let message):
            "Error: \(message)"
        }
    }
}

enum DuckingEvent: Sendable, Equatable {
    case enable
    case monitorReady
    case resumePaused
    case controlRelinquished
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
        case (.disabled, .enable), (.error, .enable):
            state = .starting
        case (.starting, .resumePaused):
            state = .pausedByFlowSound
        case (.starting, .monitorReady):
            state = .listening
        case (.ducking, .controlRelinquished), (.restoring, .controlRelinquished):
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
        default:
            break
        }

        return state
    }
}
