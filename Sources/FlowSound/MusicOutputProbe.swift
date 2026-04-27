import CoreAudio
import Foundation

struct AudioOutputMetrics: Sendable, Equatable {
    var rms: Double
    var peak: Double
}

final class NeteaseAudioOutputProbe: @unchecked Sendable {
    private let bundleIdentifier: String
    private let queue = DispatchQueue(label: "com.flowsound.netease-output-probe")
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
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
        queue.sync {
            if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
                AudioDeviceStop(aggregateDeviceID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            }
            if aggregateDeviceID != kAudioObjectUnknown {
                AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            }
            if tapID != kAudioObjectUnknown {
                AudioHardwareDestroyProcessTap(tapID)
            }
            tapID = AudioObjectID(kAudioObjectUnknown)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
            ioProcID = nil
        }
    }

    func metrics() -> AudioOutputMetrics {
        lock.lock()
        defer { lock.unlock() }
        return latestMetrics
    }

    private func startOnQueue() throws {
        try queue.sync {
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
                self?.recordMetrics(inputData)
            }
            try check(
                AudioDeviceCreateIOProcIDWithBlock(&createdIOProcID, createdAggregateDeviceID, queue, block),
                operation: "AudioDeviceCreateIOProcIDWithBlock"
            )
            ioProcID = createdIOProcID
            try check(AudioDeviceStart(createdAggregateDeviceID, createdIOProcID), operation: "AudioDeviceStart")
        }
    }

    private func recordMetrics(_ inputData: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        var sumOfSquares = 0.0
        var peak = 0.0
        var sampleCount = 0

        for buffer in buffers {
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { continue }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.stride
            let samples = data.assumingMemoryBound(to: Float32.self)
            for index in 0..<count {
                let sample = Double(samples[index])
                sumOfSquares += sample * sample
                peak = max(peak, abs(sample))
            }
            sampleCount += count
        }

        guard sampleCount > 0 else { return }
        lock.lock()
        latestMetrics = AudioOutputMetrics(rms: sqrt(sumOfSquares / Double(sampleCount)), peak: peak)
        lock.unlock()
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
