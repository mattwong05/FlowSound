import CoreAudio
import Foundation

struct AudioOutputMetrics: Sendable, Equatable {
    var rms: Double
    var peak: Double
    var sampleCount: Int = 0
    var sampledAt: TimeInterval? = nil

    func isFresh(maxAge: TimeInterval = 0.5, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard sampleCount > 0, let sampledAt, rms.isFinite, peak.isFinite else { return false }
        return now >= sampledAt && now - sampledAt <= maxAge
    }
}

final class NeteaseAudioOutputProbe: @unchecked Sendable {
    private let bundleIdentifier: String
    private let queue = DispatchQueue(label: "com.flowsound.netease-output-probe")
    private let ioQueue = DispatchQueue(label: "com.flowsound.netease-output-samples", qos: .userInitiated)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var sessionID: UUID?
    private var latestMetrics = AudioOutputMetrics(rms: 0, peak: 0)
    private let lock = NSLock()

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }

    func start() async throws {
        try await Task.detached(priority: .utility) {
            try self.startOnQueue()
        }.value
    }

    func stop() {
        queue.sync { cleanupOnQueue() }
    }

    private func cleanupOnQueue() {
        sessionID = nil
        if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        if aggregateDeviceID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateDeviceID) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        tapID = AudioObjectID(kAudioObjectUnknown)
        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        ioProcID = nil
        lock.lock()
        latestMetrics = AudioOutputMetrics(rms: 0, peak: 0)
        lock.unlock()
    }

    func metrics() -> AudioOutputMetrics {
        lock.lock()
        defer { lock.unlock() }
        return latestMetrics
    }

    private func startOnQueue() throws {
        try queue.sync {
            cleanupOnQueue()
            var started = false
            defer { if !started { cleanupOnQueue() } }
            let sessionID = UUID()
            self.sessionID = sessionID
            let processIDs = try processObjectIDs(matching: bundleIdentifier)
            guard !processIDs.isEmpty else {
                throw MusicControlAdapterError.commandFailed(
                    playerName: "Netease Cloud Music",
                    message: "No Core Audio process found for \(bundleIdentifier)."
                )
            }

            let description = CATapDescription(stereoMixdownOfProcesses: processIDs)
            description.name = "FlowSound Netease Output Probe"
            description.isMixdown = true
            description.isMono = false
            description.isPrivate = true
            description.muteBehavior = .unmuted

            var createdTapID = AudioObjectID(kAudioObjectUnknown)
            try check(AudioHardwareCreateProcessTap(description, &createdTapID), operation: "AudioHardwareCreateProcessTap")
            tapID = createdTapID
            let format = try readTapFormat(createdTapID)

            let tapUID = try readTapUID(createdTapID)
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "FlowSound Netease Output Probe",
                kAudioAggregateDeviceUIDKey: "com.flowsound.netease-output-probe.\(UUID().uuidString)",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: false,
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapUIDKey: tapUID,
                        kAudioSubTapDriftCompensationKey: true
                    ]
                ]
            ]

            var createdAggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
            try check(
                AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &createdAggregateDeviceID),
                operation: "AudioHardwareCreateAggregateDevice"
            )
            aggregateDeviceID = createdAggregateDeviceID

            var createdIOProcID: AudioDeviceIOProcID?
            let block: AudioDeviceIOBlock = { [weak self] _, inputData, _, _, _ in
                guard let measurement = PCMAnalyzer.measure(inputData, format: format) else { return }
                let now = ProcessInfo.processInfo.systemUptime
                self?.queue.async { [weak self] in
                    self?.recordMetrics(measurement, sampledAt: now, sessionID: sessionID)
                }
            }
            try check(
                AudioDeviceCreateIOProcIDWithBlock(&createdIOProcID, createdAggregateDeviceID, ioQueue, block),
                operation: "AudioDeviceCreateIOProcIDWithBlock"
            )
            ioProcID = createdIOProcID
            try check(AudioDeviceStart(createdAggregateDeviceID, createdIOProcID), operation: "AudioDeviceStart")
            started = true
        }
    }

    private func recordMetrics(_ measurement: PCMMeasurement, sampledAt: TimeInterval, sessionID: UUID) {
        guard self.sessionID == sessionID else { return }
        lock.lock()
        latestMetrics = AudioOutputMetrics(rms: measurement.rms, peak: measurement.peak, sampleCount: measurement.sampleCount, sampledAt: sampledAt)
        lock.unlock()
    }

    private func readTapFormat(_ tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), operation: "Read probe PCM format")
        guard PCMAnalyzer.isSupported(format) else { throw AudioActivityMonitorError.invalidFormat }
        return format
    }

    private func processObjectIDs(matching bundleIdentifier: String) throws -> [AudioObjectID] {
        try readAudioObjectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        ).filter { processID in
            (try? readProcessBundleID(processID)) == bundleIdentifier
        }
    }

    private func readAudioObjectIDArray(objectID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size), operation: "AudioObjectGetPropertyDataSize")
        guard size > 0 else { return [] }

        var values = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        try values.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            try check(
                AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, baseAddress),
                operation: "AudioObjectGetPropertyData"
            )
        }
        return values.filter { $0 != kAudioObjectUnknown }
    }

    private func readProcessBundleID(_ processID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        try check(
            withUnsafeMutablePointer(to: &value) { pointer in
                AudioObjectGetPropertyData(processID, &address, 0, nil, &size, pointer)
            },
            operation: "AudioObjectGetPropertyData(kAudioProcessPropertyBundleID)"
        )
        guard let value else {
            throw MusicControlAdapterError.commandFailed(playerName: "Netease Cloud Music", message: "Missing process bundle identifier.")
        }
        return value.takeRetainedValue() as String
    }

    private func readTapUID(_ tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        try check(
            withUnsafeMutablePointer(to: &value) { pointer in
                AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, pointer)
            },
            operation: "AudioObjectGetPropertyData(kAudioTapPropertyUID)"
        )
        guard let value else {
            throw MusicControlAdapterError.commandFailed(playerName: "Netease Cloud Music", message: "Missing Core Audio tap UID.")
        }
        return value.takeRetainedValue() as String
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw MusicControlAdapterError.commandFailed(
                playerName: "Netease Cloud Music",
                message: "\(operation) failed with Core Audio status \(status)."
            )
        }
    }
}
