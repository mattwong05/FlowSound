import CoreAudio
import Foundation
import Testing
@testable import FlowSound

@Test func detectorRequiresSustainedActivityAndReleasesAfterQuiet() {
    var detector = AudioSignalDetector()
    #expect(detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: 0) == nil)
    #expect(detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: 0.5) == nil)
    #expect(detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: 1) == .active)
    #expect(detector.checkQuiet(now: 2) == nil)
    #expect(detector.checkQuiet(now: 2.25) == .quiet)
    #expect(detector.checkQuiet(now: 3) == nil)
}

@Test func detectorDoesNotAccumulateIsolatedBursts() {
    var detector = AudioSignalDetector()
    for time in [0.0, 1.0, 2.0, 3.0] {
        #expect(detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: time) == nil)
    }
    #expect(detector.activity == .quiet)
}

@Test func detectorToleratesBriefAudioDynamics() {
    var detector = AudioSignalDetector()
    _ = detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: 0)
    _ = detector.record(rms: 0, threshold: 0.1, activeDuration: 1, now: 0.2)
    _ = detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: 0.5)
    #expect(detector.record(rms: 0.2, threshold: 0.1, activeDuration: 1, now: 1) == .active)
}

@Test func initialQuietRequiresObservedSamplesAndIsReportedOnce() {
    var detector = AudioSignalDetector()
    #expect(detector.checkQuiet(now: 100) == nil)
    for time in [100.0, 100.5, 101.0] {
        #expect(detector.record(rms: 0, threshold: 0.1, activeDuration: 1, now: time) == nil)
    }
    #expect(detector.record(rms: 0, threshold: 0.1, activeDuration: 1, now: 101.25) == .quiet)
    #expect(detector.record(rms: 0, threshold: 0.1, activeDuration: 1, now: 102) == nil)
}

@Test func missingSamplesAndInvalidMeasurementsDoNotConfirmInitialQuiet() {
    var detector = AudioSignalDetector()
    _ = detector.record(rms: 0, threshold: 0.1, activeDuration: 1, now: 0)
    #expect(detector.record(rms: .nan, threshold: 0.1, activeDuration: 1, now: 0.5) == nil)
    #expect(detector.record(rms: .infinity, threshold: 0.1, activeDuration: 1, now: 1) == nil)
    #expect(detector.record(rms: 0, threshold: 0.1, activeDuration: 1, now: 10) == nil)
}

@Test func pcmAnalyzerDistinguishesFloatAndSignedIntegerFormats() {
    let float = measurePCM([Float32(0.5), -0.5], format: pcmFormat(bits: 32, flags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked))
    #expect(float == PCMMeasurement(rms: 0.5, peak: 0.5, sampleCount: 2))
    let integer = measurePCM([Int16.min, Int16(0)], format: pcmFormat(bits: 16, flags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked))
    #expect(integer?.peak == 1)
    #expect(abs((integer?.rms ?? 0) - sqrt(0.5)) < 0.00001)
}

@Test func pcmAnalyzerRejectsUnknownFlagsUnsupportedFormatsAndInvalidSamples() {
    #expect(!PCMAnalyzer.isSupported(pcmFormat(bits: 16, flags: kAudioFormatFlagIsPacked)))
    #expect(!PCMAnalyzer.isSupported(pcmFormat(bits: 24, flags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked)))
    #expect(!PCMAnalyzer.isSupported(pcmFormat(bits: 32, flags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian)))
    #expect(measurePCM([Float32.nan], format: pcmFormat(bits: 32, flags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked)) == nil)
    #expect(measurePCM([Float32](), format: pcmFormat(bits: 32, flags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked)) == nil)
}

@Test func probeFreshnessDistinguishesNoSamplesFromMeasuredSilence() {
    #expect(!AudioOutputMetrics(rms: 0, peak: 0).isFresh(now: 10))
    let silence = AudioOutputMetrics(rms: 0, peak: 0, sampleCount: 512, sampledAt: 10)
    #expect(silence.isFresh(now: 10.2))
    #expect(!silence.isFresh(now: 11))
    #expect(!silence.isFresh(now: 9))
}

@Test func callbackGenerationRejectsQueuedEventsFromPreviousSession() {
    let generation = AudioCallbackGeneration()
    let previous = generation.replace()
    #expect(generation.isCurrent(previous))
    let current = generation.replace()
    #expect(!generation.isCurrent(previous))
    #expect(generation.isCurrent(current))
}

@Test func captureHealthWaitsForIdleSourcesWithoutInventingSilence() {
    var health = AudioCaptureHealth()
    health.beginSession(now: 0)
    #expect(health.check(now: 4, hasOutput: false) == nil)
    #expect(health.check(now: 5, hasOutput: false) == .waitForSamples)
    #expect(health.check(now: 30, hasOutput: false) == nil)
    let resumed = health.recordSample(now: 31)
    #expect(resumed)
    #expect(health.check(now: 31.1, hasOutput: false) == nil)
}

@Test func captureHealthBoundsSuccessfulRestartsThatStillProduceNoSamples() {
    var health = AudioCaptureHealth()
    health.beginSession(now: 0)
    _ = health.recordSample(now: 1)
    #expect(health.check(now: 6, hasOutput: true) == .recover)
    health.beginSession(now: 6)
    #expect(health.check(now: 11, hasOutput: true) == .recover)
    health.beginSession(now: 11)
    #expect(health.check(now: 16, hasOutput: true) == .fail)
}

@Test func captureHealthGivesNewOutputSourcesTimeToDeliverFirstBuffer() {
    var health = AudioCaptureHealth()
    health.beginSession(now: 0)
    #expect(health.check(now: 5, hasOutput: false) == .waitForSamples)
    #expect(health.check(now: 10, hasOutput: true) == nil)
    #expect(health.check(now: 14, hasOutput: true) == nil)
    #expect(health.check(now: 15, hasOutput: true) == .recover)
}

private func pcmFormat(bits: UInt32, flags: AudioFormatFlags) -> AudioStreamBasicDescription {
    AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: flags, mBytesPerPacket: bits / 8, mFramesPerPacket: 1, mBytesPerFrame: bits / 8, mChannelsPerFrame: 1, mBitsPerChannel: bits, mReserved: 0)
}

private func measurePCM<T>(_ samples: [T], format: AudioStreamBasicDescription) -> PCMMeasurement? {
    samples.withUnsafeBytes { bytes in
        var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes.count), mData: UnsafeMutableRawPointer(mutating: bytes.baseAddress)))
        return withUnsafePointer(to: &list) { PCMAnalyzer.measure($0, format: format) }
    }
}
