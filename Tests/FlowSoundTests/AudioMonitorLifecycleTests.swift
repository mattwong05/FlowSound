import Foundation
import Testing
@testable import FlowSound

@Test @MainActor func audioMonitorPropagatesStartupFailureAndCleansPartialResources() async {
    let trace = AudioLifecycleTrace(successfulStarts: 0)
    let monitor = CoreAudioProcessTapMonitor(lifecycle: trace.lifecycle)
    var statuses: [AudioMonitorStatus] = []
    var activities: [AudioActivity] = []
    monitor.onStatusChanged = { statuses.append($0) }
    monitor.onActivityChanged = { activities.append($0) }
    do {
        try await monitor.start(settings: .defaults)
        Issue.record("A failed tap startup must throw")
    } catch { }
    await waitForAudioCondition { statuses.last == .failed("Fixture startup failed") }
    #expect(trace.counts.starts == 1)
    #expect(trace.counts.stops == 1)
    #expect(activities.isEmpty)
    #expect(statuses == [.starting, .failed("Fixture startup failed")])
    monitor.stop()
}

@Test @MainActor func audioMonitorStopEmitsQuietAfterActiveWithoutLosingItToDeduplication() async throws {
    let trace = AudioLifecycleTrace(successfulStarts: 1)
    let monitor = CoreAudioProcessTapMonitor(lifecycle: trace.lifecycle)
    var activities: [AudioActivity] = []
    var stopped = false
    monitor.onActivityChanged = { activities.append($0) }
    monitor.onStatusChanged = { if $0 == .stopped { stopped = true } }
    try await monitor.start(settings: .defaults)
    monitor.simulateActive()
    await waitForAudioCondition { activities == [.active] }
    monitor.stop()
    await waitForAudioCondition { stopped }
    #expect(activities == [.active, .quiet])
    #expect(trace.counts.stops == 1)
}

@Test @MainActor func audioMonitorRecoveryIsBoundedAndDoesNotTreatFailureAsQuiet() async throws {
    let trace = AudioLifecycleTrace(successfulStarts: 1)
    let monitor = CoreAudioProcessTapMonitor(lifecycle: trace.lifecycle, recoveryDelays: [0.005, 0.005, 0.005])
    var statuses: [AudioMonitorStatus] = []
    var activities: [AudioActivity] = []
    monitor.onStatusChanged = { statuses.append($0) }
    monitor.onActivityChanged = { activities.append($0) }
    try await monitor.start(settings: .defaults)
    monitor.simulateActive()
    await waitForAudioCondition { activities == [.active] }
    monitor.handleConfigurationChange()
    await waitForAudioCondition { statuses.last == .failed("Fixture startup failed") }
    #expect(trace.counts.starts == 4)
    #expect(trace.counts.stops == 4)
    #expect(statuses.contains(.recovering))
    #expect(activities == [.active])
    try await Task.sleep(for: .milliseconds(30))
    #expect(trace.counts.starts == 4)
    monitor.stop()
}

@Test @MainActor func stoppingMonitorCancelsPendingRecovery() async throws {
    let trace = AudioLifecycleTrace(successfulStarts: 10)
    let monitor = CoreAudioProcessTapMonitor(lifecycle: trace.lifecycle, recoveryDelays: [0.1])
    var statuses: [AudioMonitorStatus] = []
    monitor.onStatusChanged = { statuses.append($0) }
    try await monitor.start(settings: .defaults)
    monitor.handleConfigurationChange()
    await waitForAudioCondition { statuses.last == .recovering }
    monitor.stop()
    await waitForAudioCondition { statuses.last == .stopped }
    try await Task.sleep(for: .milliseconds(150))
    #expect(trace.counts.starts == 1)
    #expect(trace.counts.stops == 1)
    #expect(statuses.last == .stopped)
}

@Test @MainActor func monitorRecoveryReturnsToRunningAfterSuccessfulRebuild() async throws {
    let trace = AudioLifecycleTrace(successfulStarts: 10)
    let monitor = CoreAudioProcessTapMonitor(lifecycle: trace.lifecycle, recoveryDelays: [0.005])
    var statuses: [AudioMonitorStatus] = []
    monitor.onStatusChanged = { statuses.append($0) }
    try await monitor.start(settings: .defaults)
    await waitForAudioCondition { statuses.last == .running }
    monitor.handleConfigurationChange()
    await waitForAudioCondition { statuses.filter { $0 == .running }.count == 2 }
    #expect(statuses == [.starting, .running, .recovering, .running])
    #expect(trace.counts.starts == 2)
    #expect(trace.counts.stops == 1)
    monitor.stop()
}

@Test @MainActor func stopInvalidatesInFlightStartupAndDropsItsCallbacks() async {
    let trace = AudioLifecycleTrace(successfulStarts: 1)
    let lifecycle = trace.lifecycle
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let monitor = CoreAudioProcessTapMonitor(lifecycle: AudioTapLifecycle(start: { settings in
        try lifecycle.start(settings)
        entered.signal()
        _ = release.wait(timeout: .now() + 2)
    }, stop: lifecycle.stop))
    var statuses: [AudioMonitorStatus] = []
    monitor.onStatusChanged = { statuses.append($0) }
    let startup = Task { @MainActor in
        do {
            try await monitor.start(settings: .defaults)
            return true
        } catch { return false }
    }
    let didEnter = await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            continuation.resume(returning: entered.wait(timeout: .now() + 1) == .success)
        }
    }
    #expect(didEnter)
    monitor.stop()
    release.signal()
    #expect(await startup.value == false)
    await waitForAudioCondition { statuses.last == .stopped }
    #expect(!statuses.contains(.running))
    #expect(trace.counts.stops == 1)
}

private enum AudioLifecycleFixtureError: LocalizedError {
    case failed
    var errorDescription: String? { "Fixture startup failed" }
}

private final class AudioLifecycleTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0
    private let successfulStarts: Int

    init(successfulStarts: Int) { self.successfulStarts = successfulStarts }

    var lifecycle: AudioTapLifecycle {
        AudioTapLifecycle(start: { [self] _ in
            lock.lock()
            starts += 1
            let shouldFail = starts > successfulStarts
            lock.unlock()
            if shouldFail { throw AudioLifecycleFixtureError.failed }
        }, stop: { [self] in
            lock.lock()
            stops += 1
            lock.unlock()
        })
    }

    var counts: (starts: Int, stops: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (starts, stops)
    }
}

@MainActor
private func waitForAudioCondition(_ condition: @MainActor () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    let deadline = ContinuousClock.now + .seconds(2)
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
    #expect(condition(), sourceLocation: sourceLocation)
}
