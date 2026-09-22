import CoreAudio
import Foundation

/// Pure timing logic: callers supply monotonic time and validated PCM measurements.
struct AudioSignalDetector {
    private(set) var activity: AudioActivity = .quiet
    private var candidateStartedAt: TimeInterval?
    private var lastAudibleAt: TimeInterval?
    private var quietCandidateStartedAt: TimeInterval?
    private var lastSampleAt: TimeInterval?
    private var hasReportedState = false

    mutating func record(rms: Double, threshold: Double, activeDuration: TimeInterval, now: TimeInterval) -> AudioActivity? {
        guard rms.isFinite, rms >= 0 else { return nil }
        if let lastSampleAt, now - lastSampleAt > 1.0 { quietCandidateStartedAt = nil }
        lastSampleAt = now
        if rms >= threshold {
            quietCandidateStartedAt = nil
            if let lastAudibleAt, now - lastAudibleAt > FlowSoundConstants.activeCandidateResetDuration, activity != .active {
                candidateStartedAt = nil
            }
            lastAudibleAt = now
            if candidateStartedAt == nil { candidateStartedAt = now }
            if activity != .active, now - (candidateStartedAt ?? now) >= activeDuration {
                activity = .active
                hasReportedState = true
                return .active
            }
        } else {
            if activity != .active, let lastAudibleAt,
               now - lastAudibleAt > FlowSoundConstants.activeCandidateResetDuration { candidateStartedAt = nil }
            if quietCandidateStartedAt == nil { quietCandidateStartedAt = now }
            if !hasReportedState, now - (quietCandidateStartedAt ?? now) >= FlowSoundConstants.monitorQuietReleaseDuration {
                hasReportedState = true
                return .quiet
            }
        }
        return nil
    }

    mutating func checkQuiet(now: TimeInterval) -> AudioActivity? {
        guard activity == .active, let lastAudibleAt,
              now - lastAudibleAt >= FlowSoundConstants.monitorQuietReleaseDuration else { return nil }
        activity = .quiet
        candidateStartedAt = nil
        return .quiet
    }
}

struct PCMMeasurement: Sendable, Equatable {
    let rms: Double
    let peak: Double
    let sampleCount: Int
}

/// Missing capture data is a health signal, never a silent audio measurement.
struct AudioCaptureHealth {
    enum Action: Equatable { case waitForSamples, recover, fail }
    private var startedAt: TimeInterval = 0
    private var lastSampleAt: TimeInterval?
    private var outputStartedAt: TimeInterval?
    private var hasCapturedSamples = false
    private var isWaiting = false
    private var missingSampleRecoveries = 0

    mutating func beginSession(now: TimeInterval) {
        startedAt = now
        lastSampleAt = nil
        outputStartedAt = nil
        isWaiting = false
    }

    mutating func recordSample(now: TimeInterval) -> Bool {
        let wasWaiting = isWaiting
        lastSampleAt = now
        hasCapturedSamples = true
        isWaiting = false
        missingSampleRecoveries = 0
        return wasWaiting
    }

    mutating func check(now: TimeInterval, hasOutput: Bool) -> Action? {
        if hasOutput {
            if outputStartedAt == nil { outputStartedAt = now }
        } else { outputStartedAt = nil }
        guard now - (lastSampleAt ?? startedAt) >= 5 else { return nil }
        if hasCapturedSamples || outputStartedAt.map({ now - $0 >= 5 }) == true {
            isWaiting = true
            guard missingSampleRecoveries < 2 else { return .fail }
            missingSampleRecoveries += 1
            return .recover
        }
        guard !isWaiting else { return nil }
        isWaiting = true
        return .waitForSamples
    }
}

/// Only explicitly supported native-endian, packed PCM is accepted.
enum PCMAnalyzer {
    static func isSupported(_ format: AudioStreamBasicDescription) -> Bool {
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mChannelsPerFrame > 0, format.mSampleRate.isFinite, format.mSampleRate > 0,
              format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
              format.mFormatFlags & kAudioFormatFlagIsPacked != 0 else { return false }
        let isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let isSigned = format.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0
        let supportedBits = isFloat ? (format.mBitsPerChannel == 32 || format.mBitsPerChannel == 64) : (isSigned && format.mBitsPerChannel == 16)
        let channelsPerBuffer = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 ? 1 : format.mChannelsPerFrame
        return supportedBits && format.mBytesPerFrame == channelsPerBuffer * (format.mBitsPerChannel / 8)
    }

    static func measure(_ input: UnsafePointer<AudioBufferList>, format: AudioStreamBasicDescription) -> PCMMeasurement? {
        guard isSupported(format) else { return nil }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let stride = Int(format.mBitsPerChannel / 8)
        var squares = 0.0
        var peak = 0.0
        var count = 0
        for buffer in buffers {
            guard buffer.mDataByteSize > 0 else { continue }
            guard let data = buffer.mData, Int(buffer.mDataByteSize) % stride == 0 else { return nil }
            let bytes = UnsafeRawBufferPointer(start: data, count: Int(buffer.mDataByteSize))
            for offset in Swift.stride(from: 0, to: bytes.count, by: stride) {
                let sample: Double
                if format.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                    sample = stride == 4 ? Double(bytes.loadUnaligned(fromByteOffset: offset, as: Float32.self)) : bytes.loadUnaligned(fromByteOffset: offset, as: Float64.self)
                } else {
                    sample = Double(bytes.loadUnaligned(fromByteOffset: offset, as: Int16.self)) / 32768.0
                }
                guard sample.isFinite else { return nil }
                squares += sample * sample
                peak = max(peak, abs(sample))
                count += 1
            }
        }
        guard count > 0, squares.isFinite else { return nil }
        return PCMMeasurement(rms: sqrt(squares / Double(count)), peak: peak, sampleCount: count)
    }
}
