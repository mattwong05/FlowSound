import AppKit
import CoreAudio
import Foundation

final class CoreAudioProcessTapMonitor: SimulatableAudioActivityMonitor, @unchecked Sendable {
    var onActivityChanged: (@MainActor (AudioActivity) -> Void)?
    var onStatusChanged: (@MainActor (AudioMonitorStatus) -> Void)?

    private let queue = DispatchQueue(label: "com.flowsound.process-tap-monitor")
    // Core Audio dispatches IO blocks synchronously. Never stop/destroy IO on this queue.
    private let ioQueue = DispatchQueue(label: "com.flowsound.process-tap-samples", qos: .userInitiated)
    private let callbackGeneration = AudioCallbackGeneration()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var timer: DispatchSourceTimer?
    private var settings = FlowSoundSettings.defaults
    private var isRunning = false
    private var wantsMonitoring = false
    private var isSleeping = false
    private var currentActivity: AudioActivity = .quiet
    private var detector = AudioSignalDetector()
    private var sessionID: UUID?
    private var monitoringMode = FlowSoundSettings.defaults.monitoringMode
    private var expandedWatchedBundleIdentifiers: [String] = []
    private var excludedBundleIdentifiers: [String] = []
    private var lastMatchedProcessLogAt: TimeInterval = 0
    private var lastPollAt: TimeInterval = 0
    private var lastPCMSampleAt: TimeInterval?
    private var captureHealth = AudioCaptureHealth()
    private var usingProcessFallback = false
    private var hasVerifiedFallbackQuiet = false
    private var lastPollHadMatchedOutput = false
    private var legacyProcessIDs: Set<AudioObjectID> = []
    private var recoveryWork: DispatchWorkItem?
    private var propertyListeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let workspaceCenter: NotificationCenter
    private var workspaceObservers: [NSObjectProtocol] = []
    private let lifecycle: AudioTapLifecycle?
    private var lifecycleNeedsCleanup = false
    private let recoveryDelays: [TimeInterval]

    @MainActor
    init(lifecycle: AudioTapLifecycle? = nil, recoveryDelays: [TimeInterval] = [0.35, 1, 2]) {
        self.lifecycle = lifecycle
        self.recoveryDelays = recoveryDelays.isEmpty ? [0.35, 1, 2] : recoveryDelays
        workspaceCenter = NSWorkspace.shared.notificationCenter
        guard lifecycle == nil else { return }
        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in self?.suspendForSleep() }
        })
        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in
                guard let self else { return }
                self.isSleeping = false
                self.captureHealth = AudioCaptureHealth()
                self.scheduleRecovery(reason: "system wake")
            }
        })
    }

    deinit {
        for observer in workspaceObservers { workspaceCenter.removeObserver(observer) }
    }

    func start(settings: FlowSoundSettings) async throws {
        try Task.checkCancellation()
        let requestID = callbackGeneration.replace()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard self.callbackGeneration.isCurrent(requestID) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.cleanupOnQueue()
                self.sessionID = requestID
                self.settings = settings
                self.monitoringMode = settings.monitoringMode
                self.expandedWatchedBundleIdentifiers = FlowSoundSettings.effectiveWatchedBundleIdentifiers(for: settings)
                self.excludedBundleIdentifiers = Self.excludedBundleIdentifiers(settings: settings)
                self.wantsMonitoring = true
                self.isSleeping = false
                self.captureHealth = AudioCaptureHealth()
                self.emitStatus(.starting)
                do {
                    try self.startOnQueue(settings: settings, sessionID: requestID)
                    self.emitStatus(.running)
                    continuation.resume()
                } catch {
                    self.cleanupOnQueue()
                    self.wantsMonitoring = false
                    self.emitStatus(.failed(error.localizedDescription))
                    continuation.resume(throwing: error)
                }
            }
        }
        if Task.isCancelled {
            if callbackGeneration.isCurrent(requestID) { stop() }
            throw CancellationError()
        }
    }

    func stop() {
        let requestID = callbackGeneration.replace()
        queue.async { [weak self] in
            guard let self, self.callbackGeneration.isCurrent(requestID) else { return }
            self.sessionID = requestID
            self.wantsMonitoring = false
            self.cleanupOnQueue()
            self.emit(.quiet)
            self.emitStatus(.stopped)
        }
    }

    func simulateActive() {
        queue.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.emit(.active)
        }
    }

    func simulateQuiet() {
        queue.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.emit(.quiet)
        }
    }

    private func process(_ measurement: PCMMeasurement, sampledAt now: TimeInterval, sessionID: UUID) {
        guard isRunning, self.sessionID == sessionID, callbackGeneration.isCurrent(sessionID) else { return }
        lastPCMSampleAt = now
        usingProcessFallback = false
        hasVerifiedFallbackQuiet = false
        if captureHealth.recordSample(now: now) { emitStatus(.running) }
        recordAudioSignal(rms: measurement.rms, now: now)
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
        guard callbackGeneration.isCurrent(sessionID) else { throw CancellationError() }
        if let lifecycle {
            lifecycleNeedsCleanup = true
            try lifecycle.start(settings)
            guard callbackGeneration.isCurrent(sessionID) else { throw CancellationError() }
            isRunning = true
            detector = AudioSignalDetector()
            lastPCMSampleAt = nil
            return
        }
        let watchedBundleIdentifiers = FlowSoundSettings.effectiveWatchedBundleIdentifiers(for: settings)
        let excludedBundleIdentifiers = Self.excludedBundleIdentifiers(settings: settings)
        let description = try makeTapDescription(
            settings: settings,
            watchedBundleIdentifiers: watchedBundleIdentifiers,
            excludedBundleIdentifiers: excludedBundleIdentifiers
        )
        description.isMixdown = true
        description.isMono = false
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var createdTapID = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(description, &createdTapID), operation: "AudioHardwareCreateProcessTap")
        guard self.sessionID == sessionID, callbackGeneration.isCurrent(sessionID) else {
            AudioHardwareDestroyProcessTap(createdTapID)
            throw CancellationError()
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
        guard self.sessionID == sessionID, callbackGeneration.isCurrent(sessionID) else {
            AudioHardwareDestroyAggregateDevice(createdAggregateDeviceID)
            throw CancellationError()
        }
        aggregateDeviceID = createdAggregateDeviceID
        let format = try readTapFormat(tapID)

        var createdIOProcID: AudioDeviceIOProcID?
        let block: AudioDeviceIOBlock = { [weak self] _, inputData, _, _, _ in
            guard let measurement = PCMAnalyzer.measure(inputData, format: format) else { return }
            let now = ProcessInfo.processInfo.systemUptime
            self?.queue.async { [weak self] in
                self?.process(measurement, sampledAt: now, sessionID: sessionID)
            }
        }
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&createdIOProcID, aggregateDeviceID, ioQueue, block),
            operation: "AudioDeviceCreateIOProcIDWithBlock"
        )
        guard self.sessionID == sessionID, callbackGeneration.isCurrent(sessionID) else {
            if let createdIOProcID {
                AudioDeviceDestroyIOProcID(createdAggregateDeviceID, createdIOProcID)
            }
            throw CancellationError()
        }
        ioProcID = createdIOProcID

        FlowSoundDiagnostics.log("Core Audio process tap starting device IO")
        try check(AudioDeviceStart(aggregateDeviceID, ioProcID), operation: "AudioDeviceStart")
        isRunning = true
        detector = AudioSignalDetector()
        lastPCMSampleAt = nil
        usingProcessFallback = false
        hasVerifiedFallbackQuiet = false
        lastPollHadMatchedOutput = false
        captureHealth.beginSession(now: ProcessInfo.processInfo.systemUptime)
        try installPropertyListeners(sessionID: sessionID)
        startQuietTimer()
        FlowSoundDiagnostics.log(Self.startedLogMessage(settings: settings, watchedBundleIDs: watchedBundleIdentifiers, excludedBundleIDs: excludedBundleIdentifiers))
    }

    private func makeTapDescription(
        settings: FlowSoundSettings,
        watchedBundleIdentifiers: [String],
        excludedBundleIdentifiers: [String]
    ) throws -> CATapDescription {
        if #available(macOS 26.0, *) {
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
            description.isProcessRestoreEnabled = true
            return description
        }

        let processIDs: [AudioObjectID]
        let description: CATapDescription
        switch settings.monitoringMode {
        case .allNonMusic:
            processIDs = try processObjectIDs(matching: Set(excludedBundleIdentifiers))
            description = CATapDescription(stereoGlobalTapButExcludeProcesses: processIDs)
        case .watchedApps:
            processIDs = try processObjectIDs(matching: Set(watchedBundleIdentifiers))
            description = CATapDescription(stereoMixdownOfProcesses: processIDs)
        }
        legacyProcessIDs = Set(processIDs)
        description.name = "FlowSound Watched Apps"
        FlowSoundDiagnostics.log("Core Audio process tap using process IDs for macOS 15-25: \(processIDs.map(String.init).joined(separator: ", "))")
        return description
    }

    private func cleanupOnQueue() {
        isRunning = false
        recoveryWork?.cancel()
        recoveryWork = nil
        timer?.cancel()
        timer = nil
        if lifecycleNeedsCleanup {
            lifecycle?.stop()
            lifecycleNeedsCleanup = false
        }
        for (objectID, var address, block) in propertyListeners {
            AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
        }
        propertyListeners.removeAll()
        if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        if aggregateDeviceID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateDeviceID) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        tapID = AudioObjectID(kAudioObjectUnknown)
        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        ioProcID = nil
        detector = AudioSignalDetector()
        lastMatchedProcessLogAt = 0
        lastPollAt = 0
        lastPCMSampleAt = nil
    }

    private func checkQuietTimeout() {
        guard isRunning else { return }
        pollRunningOutputProcessesIfNeeded()
        let now = ProcessInfo.processInfo.systemUptime
        // A missing callback is not a silent measurement.
        if let lastPCMSampleAt, now - lastPCMSampleAt <= 0.25,
           let activity = detector.checkQuiet(now: now) { emit(activity) }
        switch captureHealth.check(now: now, hasOutput: lastPollHadMatchedOutput) {
        case .waitForSamples:
            if !hasVerifiedFallbackQuiet { emitStatus(.starting) }
        case .recover:
            scheduleRecovery(reason: "capture samples stopped arriving")
        case .fail:
            cleanupOnQueue()
            wantsMonitoring = false
            emitStatus(.failed("Audio capture is not delivering samples. Check System Audio Capture permission and the output device, then enable FlowSound again."))
        case nil:
            break
        }
    }

    private func emit(_ activity: AudioActivity, force: Bool = false) {
        guard let sessionID, force || currentActivity != activity else { return }
        currentActivity = activity
        DispatchQueue.main.async { [weak self] in
            guard let self, self.callbackGeneration.isCurrent(sessionID) else { return }
            self.onActivityChanged?(activity)
        }
    }

    private func emitStatus(_ status: AudioMonitorStatus) {
        guard let sessionID else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.callbackGeneration.isCurrent(sessionID) else { return }
            self.onStatusChanged?(status)
        }
    }

    private func recordAudioSignal(rms: Double, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if let activity = detector.record(rms: rms, threshold: settings.activeThreshold, activeDuration: settings.activeDuration, now: now) {
            if usingProcessFallback { emitStatus(.running) }
            emit(activity, force: true)
        }
    }

    private func installPropertyListeners(sessionID: UUID) throws {
        try listen(objectID: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice, sessionID: sessionID)
        try listen(objectID: tapID, selector: kAudioTapPropertyFormat, sessionID: sessionID)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID), operation: "Read default output device")
        if deviceID != kAudioObjectUnknown {
            try listen(objectID: deviceID, selector: kAudioDevicePropertyNominalSampleRate, sessionID: sessionID)
            try listen(objectID: deviceID, selector: kAudioDevicePropertyDeviceIsAlive, sessionID: sessionID)
        }
        if #unavailable(macOS 26.0) {
            try listen(objectID: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyProcessObjectList, sessionID: sessionID)
        }
    }

    private func listen(objectID: AudioObjectID, selector: AudioObjectPropertySelector, sessionID: UUID) throws {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, self.sessionID == sessionID, self.callbackGeneration.isCurrent(sessionID) else { return }
            if selector == kAudioHardwarePropertyProcessObjectList {
                let identifiers = self.monitoringMode == .watchedApps ? self.expandedWatchedBundleIdentifiers : self.excludedBundleIdentifiers
                guard let current = try? self.processObjectIDs(matching: Set(identifiers)), Set(current) != self.legacyProcessIDs else { return }
            }
            self.handleConfigurationChange()
        }
        try check(AudioObjectAddPropertyListenerBlock(objectID, &address, queue, block), operation: "Listen for audio configuration changes")
        propertyListeners.append((objectID, address, block))
    }

    private func suspendForSleep() {
        isSleeping = true
        guard wantsMonitoring else { return }
        sessionID = callbackGeneration.replace()
        cleanupOnQueue()
        emitStatus(.recovering)
    }

    /// The same entry point is used by Core Audio listeners and device-free lifecycle tests.
    func handleConfigurationChange() {
        let token = callbackGeneration.current()
        queue.async { [weak self] in
            guard let self, self.callbackGeneration.isCurrent(token) else { return }
            self.scheduleRecovery(reason: "audio configuration changed")
        }
    }

    private func scheduleRecovery(reason: String) {
        guard wantsMonitoring, !isSleeping, recoveryWork == nil else { return }
        let token = callbackGeneration.replace()
        sessionID = token
        isRunning = false
        emitStatus(.recovering)
        FlowSoundDiagnostics.log("Audio monitoring recovering: \(reason)")
        scheduleRecoveryAttempt(sessionID: token, attempt: 1, delay: recoveryDelays[0])
    }

    private func scheduleRecoveryAttempt(sessionID: UUID, attempt: Int, delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.wantsMonitoring, !self.isSleeping, self.callbackGeneration.isCurrent(sessionID) else { return }
            self.cleanupOnQueue()
            do {
                try self.startOnQueue(settings: self.settings, sessionID: sessionID)
                self.emitStatus(.running)
            } catch {
                self.cleanupOnQueue()
                if attempt < self.recoveryDelays.count {
                    self.scheduleRecoveryAttempt(sessionID: sessionID, attempt: attempt + 1, delay: self.recoveryDelays[attempt])
                } else {
                    self.wantsMonitoring = false
                    self.emitStatus(.failed(error.localizedDescription))
                }
            }
        }
        recoveryWork = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func pollRunningOutputProcessesIfNeeded() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPollAt >= 0.5 else { return }
        lastPollAt = now

        do {
            let outputProcesses = try runningOutputProcesses()
            recordRecentAudioSources(outputProcesses, now: now)
            let watched = Set(expandedWatchedBundleIdentifiers)
            let excluded = Set(excludedBundleIdentifiers)
            let matches = outputProcesses.filter {
                isWatchedProcess(bundleID: $0.bundleID, watched: watched, excluded: excluded)
            }
            lastPollHadMatchedOutput = !matches.isEmpty
            guard !matches.isEmpty else {
                // A successful process query confirms the fallback's output source stopped.
                // This is distinct from inferring silence from missing PCM callbacks.
                if usingProcessFallback, let activity = detector.checkQuiet(now: now) {
                    emitStatus(.running)
                    emit(activity)
                    usingProcessFallback = false
                    hasVerifiedFallbackQuiet = true
                }
                return
            }

            if now - lastMatchedProcessLogAt >= 3.0 {
                lastMatchedProcessLogAt = now
                let description = matches
                    .map { "\($0.bundleID)(pid=\($0.pid))" }
                    .joined(separator: ", ")
                FlowSoundDiagnostics.log("Core Audio matched watched output process: \(description)")
            }

            if monitoringMode == .watchedApps,
               lastPCMSampleAt.map({ now - $0 > 1.0 }) ?? true {
                // Output IO is only a fallback when fresh PCM is unavailable, never an
                // override of a real silent buffer from the tap.
                usingProcessFallback = true
                hasVerifiedFallbackQuiet = false
                recordAudioSignal(rms: max(settings.activeThreshold, 0.001))
            }
        } catch {
            if now - lastMatchedProcessLogAt >= 10.0 {
                lastMatchedProcessLogAt = now
                FlowSoundDiagnostics.log("Core Audio process output polling failed: \(error.localizedDescription)")
            }
        }
    }

    private func runningOutputProcesses() throws -> [AudioProcessSnapshot] {
        let processIDs = try readAudioObjectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        )

        var matches: [AudioProcessSnapshot] = []
        for processID in processIDs {
            guard let bundleID = try? readProcessBundleID(processID),
                  (try? readProcessIsRunningOutput(processID)) == true
            else {
                continue
            }

            let pid = (try? readProcessPID(processID)) ?? 0
            matches.append(AudioProcessSnapshot(pid: pid, bundleID: bundleID))
        }
        return matches
    }

    private func recordRecentAudioSources(_ snapshots: [AudioProcessSnapshot], now: TimeInterval) {
        let watched = Set(expandedWatchedBundleIdentifiers)
        let excluded = Set(excludedBundleIdentifiers)
        let selectedMusic = Set(settings.controlledMusicPlayer.bundleIdentifiers)

        for snapshot in snapshots {
            let status: RecentAudioSourceStatus
            if selectedMusic.contains(snapshot.bundleID) {
                status = .selectedMusicApp
            } else if excluded.contains(snapshot.bundleID) {
                status = .excluded
            } else if isWatchedProcess(bundleID: snapshot.bundleID, watched: watched, excluded: excluded) {
                status = .watched
            } else {
                status = .detected
            }
            RecentAudioSourceStore.shared.record(
                bundleIdentifier: snapshot.bundleID,
                pid: snapshot.pid,
                status: status,
                now: now
            )
        }
    }

    private func processObjectIDs(matching bundleIdentifiers: Set<String>) throws -> [AudioObjectID] {
        guard !bundleIdentifiers.isEmpty else { return [] }
        let processIDs = try readAudioObjectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        )

        return processIDs.filter { processID in
            guard let bundleID = try? readProcessBundleID(processID) else { return false }
            return bundleIdentifiers.contains(bundleID)
        }
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
        guard PCMAnalyzer.isSupported(format) else { throw AudioActivityMonitorError.invalidFormat }
        FlowSoundDiagnostics.log("Core Audio tap format: channels=\(format.mChannelsPerFrame), sampleRate=\(format.mSampleRate), bytesPerFrame=\(format.mBytesPerFrame), flags=\(format.mFormatFlags)")
        return format
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw AudioActivityMonitorError.coreAudioFailure(operation: operation, status: status)
        }
    }

    private static func excludedBundleIdentifiers(settings: FlowSoundSettings) -> [String] {
        FlowSoundSettings.effectiveExcludedBundleIdentifiers(for: settings)
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
        let value = UInt32(selector)
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

/// Invalidates already-enqueued main-actor callbacks synchronously on stop/restart.
final class AudioCallbackGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var value = UUID()

    func replace() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        value = UUID()
        return value
    }

    func isCurrent(_ candidate: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value == candidate
    }

    func current() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// A small lifecycle seam lets tests exercise failure, cleanup, cancellation and retries
/// without creating taps, recording audio or touching the user's audio devices.
struct AudioTapLifecycle: Sendable {
    let start: @Sendable (FlowSoundSettings) throws -> Void
    let stop: @Sendable () -> Void
}
