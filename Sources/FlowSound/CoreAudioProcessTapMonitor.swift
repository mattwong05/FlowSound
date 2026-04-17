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
    private var monitoringMode = FlowSoundSettings.defaults.monitoringMode
    private var expandedWatchedBundleIdentifiers = FlowSoundSettings.expandedWatchedBundleIdentifiers(FlowSoundSettings.defaults.watchedBundleIdentifiers)
    private var excludedBundleIdentifiers = FlowSoundSettings.defaultExcludedBundleIdentifiers
    private var lastActivityLogAt: TimeInterval = 0
    private var lastMatchedProcessLogAt: TimeInterval = 0
    private var lastPollAt: TimeInterval = 0
    private var lastProcessOutputSignalAt: TimeInterval = 0

    func start(settings: FlowSoundSettings) throws {
        let sessionID = UUID()
        let expandedBundleIDs = FlowSoundSettings.expandedWatchedBundleIdentifiers(settings.watchedBundleIdentifiers)
        let excludedBundleIDs = Self.excludedBundleIdentifiers(settings: settings)
        FlowSoundDiagnostics.log(Self.startLogMessage(settings: settings, expandedBundleIDs: expandedBundleIDs, excludedBundleIDs: excludedBundleIDs))
        queue.async { [weak self] in
            guard let self else { return }
            self.cleanupOnQueue(emitQuiet: false)
            self.sessionID = sessionID
            self.settings = settings
            self.monitoringMode = settings.monitoringMode
            self.expandedWatchedBundleIdentifiers = expandedBundleIDs
            self.excludedBundleIdentifiers = excludedBundleIDs
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
        recordAudioSignal(rms: rms, source: "tap")
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
        let watchedBundleIdentifiers = FlowSoundSettings.expandedWatchedBundleIdentifiers(settings.watchedBundleIdentifiers)
        let excludedBundleIdentifiers = Self.excludedBundleIdentifiers(settings: settings)
        let description = CATapDescription()
        description.name = "FlowSound Watched Apps"
        switch settings.monitoringMode {
        case .allNonMusic:
            description.bundleIDs = excludedBundleIdentifiers
            description.isExclusive = true
        case .watchedApps:
            description.bundleIDs = watchedBundleIdentifiers
            description.isExclusive = false
        }
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
        FlowSoundDiagnostics.log(Self.startedLogMessage(settings: settings, watchedBundleIDs: watchedBundleIdentifiers, excludedBundleIDs: excludedBundleIdentifiers))
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
        monitoringMode = FlowSoundSettings.defaults.monitoringMode
        activeCandidateStartedAt = nil
        lastAudibleAt = nil
        lastActivityLogAt = 0
        lastMatchedProcessLogAt = 0
        lastPollAt = 0
        lastProcessOutputSignalAt = 0

        if shouldEmitQuiet {
            emit(.quiet)
        }
    }

    private func checkQuietTimeout() {
        pollRunningOutputProcessesIfNeeded()
        guard currentActivity == .active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let lastAudibleAt = lastAudibleAt ?? now
        if now - lastAudibleAt >= FlowSoundConstants.monitorQuietReleaseDuration {
            activeCandidateStartedAt = nil
            emit(.quiet)
        }
    }

    private func emit(_ activity: AudioActivity) {
        guard currentActivity != activity else { return }
        currentActivity = activity
        FlowSoundDiagnostics.log("Core Audio activity changed: \(activity == .active ? "active" : "quiet")")
        Task { @MainActor [onActivityChanged] in
            onActivityChanged?(activity)
        }
    }

    private func recordAudioSignal(rms: Double, source: String) {
        let now = ProcessInfo.processInfo.systemUptime

        if rms >= settings.activeThreshold {
            lastAudibleAt = now
            if activeCandidateStartedAt == nil {
                activeCandidateStartedAt = now
                FlowSoundDiagnostics.log("Core Audio active candidate started from \(source), rms=\(Self.format(rms)), threshold=\(Self.format(settings.activeThreshold))")
            } else if now - lastActivityLogAt >= 2.0 {
                lastActivityLogAt = now
                FlowSoundDiagnostics.log("Core Audio audible from \(source), rms=\(Self.format(rms)), threshold=\(Self.format(settings.activeThreshold))")
            }

            if currentActivity != .active,
               let startedAt = activeCandidateStartedAt,
               now - startedAt >= settings.activeDuration {
                emit(.active)
            }
        } else if currentActivity != .active {
            let lastSignalAt = max(lastAudibleAt ?? 0, lastProcessOutputSignalAt)
            if lastSignalAt == 0 || now - lastSignalAt > FlowSoundConstants.activeCandidateResetDuration {
                activeCandidateStartedAt = nil
            }
        }
    }

    private func pollRunningOutputProcessesIfNeeded() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPollAt >= 0.5 else { return }
        lastPollAt = now

        do {
            let matches = try runningOutputProcesses()
            guard !matches.isEmpty else { return }

            if now - lastMatchedProcessLogAt >= 3.0 {
                lastMatchedProcessLogAt = now
                let description = matches
                    .map { "\($0.bundleID)(pid=\($0.pid))" }
                    .joined(separator: ", ")
                FlowSoundDiagnostics.log("Core Audio matched watched output process: \(description)")
            }

            if monitoringMode == .watchedApps {
                // Some apps, including Safari, output through helper processes whose tap buffers can
                // be delayed or silent until the helper is included. Treat active output IO as a
                // conservative fallback signal in watched-app-only mode. All-apps mode should rely on
                // RMS from the exclusive tap so stale process-output state does not stretch quiet time.
                lastProcessOutputSignalAt = now
                recordAudioSignal(rms: max(settings.activeThreshold, 0.001), source: "process-output")
            }
        } catch {
            if now - lastMatchedProcessLogAt >= 10.0 {
                lastMatchedProcessLogAt = now
                FlowSoundDiagnostics.log("Core Audio process output polling failed: \(error.localizedDescription)")
            }
        }
    }

    private func runningOutputProcesses() throws -> [AudioProcessSnapshot] {
        let watched = Set(expandedWatchedBundleIdentifiers)
        let excluded = Set(excludedBundleIdentifiers)
        let processIDs = try readAudioObjectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        )

        var matches: [AudioProcessSnapshot] = []
        for processID in processIDs {
            guard let bundleID = try? readProcessBundleID(processID),
                  isWatchedProcess(bundleID: bundleID, watched: watched, excluded: excluded),
                  (try? readProcessIsRunningOutput(processID)) == true
            else {
                continue
            }

            let pid = (try? readProcessPID(processID)) ?? 0
            matches.append(AudioProcessSnapshot(pid: pid, bundleID: bundleID))
        }
        return matches
    }

    private func isWatchedProcess(bundleID: String, watched: Set<String>, excluded: Set<String>) -> Bool {
        switch monitoringMode {
        case .allNonMusic:
            !excluded.contains(bundleID)
        case .watchedApps:
            watched.contains(bundleID)
        }
    }

    private func readAudioObjectIDArray(objectID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size), operation: "AudioObjectGetPropertyDataSize(\(Self.fourCharacterCode(selector)))")
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.stride
        var values = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        try values.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            try check(
                AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, baseAddress),
                operation: "AudioObjectGetPropertyData(\(Self.fourCharacterCode(selector)))"
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
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(processID, &address, 0, nil, &size, pointer)
        }
        try check(status, operation: "AudioObjectGetPropertyData(kAudioProcessPropertyBundleID)")
        guard let value else { throw AudioActivityMonitorError.missingProcessBundleID }
        return value.takeRetainedValue() as String
    }

    private func readProcessPID(_ processID: AudioObjectID) throws -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = pid_t(0)
        var size = UInt32(MemoryLayout<pid_t>.size)
        try check(
            AudioObjectGetPropertyData(processID, &address, 0, nil, &size, &pid),
            operation: "AudioObjectGetPropertyData(kAudioProcessPropertyPID)"
        )
        return pid
    }

    private func readProcessIsRunningOutput(_ processID: AudioObjectID) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunningOutput: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(
            AudioObjectGetPropertyData(processID, &address, 0, nil, &size, &isRunningOutput),
            operation: "AudioObjectGetPropertyData(kAudioProcessPropertyIsRunningOutput)"
        )
        return isRunningOutput != 0
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

    private static func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private static func excludedBundleIdentifiers(settings: FlowSoundSettings) -> [String] {
        var identifiers = FlowSoundSettings.validExcludedBundleIdentifiers(settings.excludedBundleIdentifiers)
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            identifiers.append(bundleIdentifier)
        }
        return FlowSoundSettings.normalizedBundleIdentifiers(identifiers)
    }

    private static func startLogMessage(
        settings: FlowSoundSettings,
        expandedBundleIDs: [String],
        excludedBundleIDs: [String]
    ) -> String {
        switch settings.monitoringMode {
        case .allNonMusic:
            "Core Audio process tap setup scheduled for all apps except \(excludedBundleIDs.joined(separator: ", "))"
        case .watchedApps:
            "Core Audio process tap setup scheduled for \(expandedBundleIDs.joined(separator: ", "))"
        }
    }

    private static func startedLogMessage(
        settings: FlowSoundSettings,
        watchedBundleIDs: [String],
        excludedBundleIDs: [String]
    ) -> String {
        switch settings.monitoringMode {
        case .allNonMusic:
            "Core Audio process tap started for all apps except \(excludedBundleIDs.joined(separator: ", "))"
        case .watchedApps:
            "Core Audio process tap started for \(watchedBundleIDs.joined(separator: ", "))"
        }
    }

    private static func fourCharacterCode(_ selector: AudioObjectPropertySelector) -> String {
        let value = UInt32(selector).bigEndian
        let characters: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        guard characters.allSatisfy({ $0 >= 32 && $0 <= 126 }) else {
            return "\(selector)"
        }
        return String(bytes: characters, encoding: .macOSRoman) ?? "\(selector)"
    }
}

private struct AudioProcessSnapshot {
    var pid: pid_t
    var bundleID: String
}
