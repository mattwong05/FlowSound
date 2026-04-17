import CoreAudio
import Foundation

final class CoreAudioProcessTapMonitor: SimulatableAudioActivityMonitor, @unchecked Sendable {
    var onActivityChanged: (@MainActor (AudioActivity) -> Void)?

    private let queue = DispatchQueue(label: "com.flowsound.process-tap-monitor")
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var timer: DispatchSourceTimer?
    private var settings = FlowSoundSettings.defaults
    private var isRunning = false
    private var currentActivity: AudioActivity = .quiet
    private var activeCandidateStartedAt: TimeInterval?
    private var lastAudibleAt: TimeInterval?
    private var tapFormat: AudioStreamBasicDescription?
    private var sessionID: UUID?

    func start(settings: FlowSoundSettings) throws {
        let sessionID = UUID()
        FlowSoundDiagnostics.log("Core Audio process tap setup scheduled")
        queue.async { [weak self] in
            guard let self else { return }
            self.cleanupOnQueue(emitQuiet: false)
            self.sessionID = sessionID
            self.settings = settings
            self.isRunning = true

            do {
                try self.startOnQueue(settings: settings, sessionID: sessionID)
            } catch {
                FlowSoundDiagnostics.log("Core Audio process tap setup failed: \(error.localizedDescription)")
                self.cleanupOnQueue(emitQuiet: true)
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.cleanupOnQueue(emitQuiet: true)
        }
    }

    func simulateActive() {
        emit(.active)
    }

    func simulateQuiet() {
        emit(.quiet)
    }

    private func process(_ inputData: UnsafePointer<AudioBufferList>) {
        guard isRunning else { return }
        let rms = calculateRMS(inputData)
        let now = ProcessInfo.processInfo.systemUptime

        if rms >= settings.activeThreshold {
            lastAudibleAt = now
            if activeCandidateStartedAt == nil {
                activeCandidateStartedAt = now
            }

            if currentActivity != .active,
               let startedAt = activeCandidateStartedAt,
               now - startedAt >= settings.activeDuration {
                emit(.active)
            }
        } else if currentActivity != .active {
            activeCandidateStartedAt = nil
        }
    }

    private func calculateRMS(_ inputData: UnsafePointer<AudioBufferList>) -> Double {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        var sumOfSquares = 0.0
        var sampleCount = 0

        for buffer in buffers {
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { continue }
            let byteCount = Int(buffer.mDataByteSize)

            if tapFormat?.mFormatID == kAudioFormatLinearPCM,
               tapFormat?.mFormatFlags ?? 0 & kAudioFormatFlagIsFloat != 0 {
                let count = byteCount / MemoryLayout<Float32>.stride
                let samples = data.assumingMemoryBound(to: Float32.self)
                for index in 0..<count {
                    let sample = Double(samples[index])
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            } else {
                let count = byteCount / MemoryLayout<Int16>.stride
                let samples = data.assumingMemoryBound(to: Int16.self)
                for index in 0..<count {
                    let sample = Double(samples[index]) / Double(Int16.max)
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            }
        }

        guard sampleCount > 0 else { return 0 }
        return sqrt(sumOfSquares / Double(sampleCount))
    }

    private func startQuietTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.checkQuietTimeout()
        }
        timer.resume()
        self.timer = timer
    }

    private func startOnQueue(settings: FlowSoundSettings, sessionID: UUID) throws {
        let description = CATapDescription()
        description.name = "FlowSound Watched Apps"
        description.bundleIDs = settings.watchedBundleIdentifiers
        description.isExclusive = false
        description.isMixdown = true
        description.isMono = false
        description.isPrivate = true
        description.isProcessRestoreEnabled = true
        description.muteBehavior = .unmuted

        var createdTapID = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(description, &createdTapID), operation: "AudioHardwareCreateProcessTap")
        guard self.sessionID == sessionID else {
            AudioHardwareDestroyProcessTap(createdTapID)
            return
        }
        tapID = createdTapID

        let tapUID = try readTapUID(tapID)
        let aggregateUID = "com.flowsound.tap.\(UUID().uuidString)"
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "FlowSound Process Tap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
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
        guard self.sessionID == sessionID else {
            AudioHardwareDestroyAggregateDevice(createdAggregateDeviceID)
            return
        }
        aggregateDeviceID = createdAggregateDeviceID
        tapFormat = try readTapFormat(tapID)

        var createdIOProcID: AudioDeviceIOProcID?
        let block: AudioDeviceIOBlock = { [weak self] _, inputData, _, _, _ in
            self?.process(inputData)
        }
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&createdIOProcID, aggregateDeviceID, queue, block),
            operation: "AudioDeviceCreateIOProcIDWithBlock"
        )
        guard self.sessionID == sessionID else {
            if let createdIOProcID {
                AudioDeviceDestroyIOProcID(createdAggregateDeviceID, createdIOProcID)
            }
            return
        }
        ioProcID = createdIOProcID

        startQuietTimer()
        FlowSoundDiagnostics.log("Core Audio process tap starting device IO")
        try check(AudioDeviceStart(aggregateDeviceID, ioProcID), operation: "AudioDeviceStart")
        let watchedApps = settings.watchedBundleIdentifiers.joined(separator: ", ")
        FlowSoundDiagnostics.log("Core Audio process tap started for \(watchedApps)")
    }

    private func cleanupOnQueue(emitQuiet shouldEmitQuiet: Bool) {
        timer?.cancel()
        timer = nil

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
        tapFormat = nil
        sessionID = nil
        isRunning = false
        currentActivity = .quiet
        activeCandidateStartedAt = nil
        lastAudibleAt = nil

        if shouldEmitQuiet {
            emit(.quiet)
        }
    }

    private func checkQuietTimeout() {
        guard currentActivity == .active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let lastAudibleAt = lastAudibleAt ?? now
        if now - lastAudibleAt >= FlowSoundConstants.monitorQuietReleaseDuration {
            activeCandidateStartedAt = nil
            emit(.quiet)
        }
    }

    private func emit(_ activity: AudioActivity) {
        currentActivity = activity
        Task { @MainActor [onActivityChanged] in
            onActivityChanged?(activity)
        }
    }

    private func readTapUID(_ tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, pointer)
        }
        try check(status, operation: "AudioObjectGetPropertyData(kAudioTapPropertyUID)")
        guard let value else { throw AudioActivityMonitorError.missingTapUID }
        return value.takeRetainedValue() as String
    }

    private func readTapFormat(_ tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format)
        try check(status, operation: "AudioObjectGetPropertyData(kAudioTapPropertyFormat)")
        guard format.mBytesPerFrame > 0 else { throw AudioActivityMonitorError.invalidFormat }
        FlowSoundDiagnostics.log("Core Audio tap format: channels=\(format.mChannelsPerFrame), sampleRate=\(format.mSampleRate), bytesPerFrame=\(format.mBytesPerFrame), flags=\(format.mFormatFlags)")
        return format
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw AudioActivityMonitorError.coreAudioFailure(operation: operation, status: status)
        }
    }
}
