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

protocol SimulatableAudioActivityMonitor: AudioActivityMonitor {
    func simulateActive()
    func simulateQuiet()
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
        let value = UInt32(bitPattern: status.bigEndian)
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

final class ManualAudioActivityMonitor: SimulatableAudioActivityMonitor {
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
