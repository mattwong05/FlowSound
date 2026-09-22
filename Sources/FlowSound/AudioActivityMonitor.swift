import Foundation

enum AudioActivity: Sendable, Equatable {
    case active
    case quiet
}

enum AudioMonitorStatus: Sendable, Equatable {
    case stopped
    case starting
    case running
    case recovering
    case failed(String)
}

protocol AudioActivityMonitor: AnyObject {
    @MainActor var onActivityChanged: (@MainActor (AudioActivity) -> Void)? { get set }
    @MainActor var onStatusChanged: (@MainActor (AudioMonitorStatus) -> Void)? { get set }

    @MainActor func start(settings: FlowSoundSettings) async throws
    @MainActor func stop()
}

extension AudioActivityMonitor {
    @MainActor var onStatusChanged: (@MainActor (AudioMonitorStatus) -> Void)? {
        get { nil }
        set { }
    }
}

protocol SimulatableAudioActivityMonitor: AudioActivityMonitor {
    @MainActor func simulateActive()
    @MainActor func simulateQuiet()
}

enum AudioActivityMonitorError: LocalizedError {
    case processTapUnavailable
    case coreAudioFailure(operation: String, status: OSStatus)
    case missingTapUID
    case missingProcessBundleID
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .processTapUnavailable:
            "Core Audio process tap monitoring is not wired yet."
        case .coreAudioFailure(let operation, let status):
            "\(operation) failed with Core Audio status \(status) (\(Self.fourCharacterCode(status)))."
        case .missingTapUID:
            "Core Audio did not return a tap UID."
        case .missingProcessBundleID:
            "Core Audio did not return a process bundle identifier."
        case .invalidFormat:
            "Core Audio returned an unsupported tap format."
        }
    }

    private static func fourCharacterCode(_ status: OSStatus) -> String {
        let value = UInt32(bitPattern: status)
        let characters: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        guard characters.allSatisfy({ $0 >= 32 && $0 <= 126 }) else {
            return "\(status)"
        }
        return String(bytes: characters, encoding: .macOSRoman) ?? "\(status)"
    }
}

@MainActor final class ManualAudioActivityMonitor: SimulatableAudioActivityMonitor {
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
