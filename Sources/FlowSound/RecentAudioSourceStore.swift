import Foundation

enum RecentAudioSourceStatus: Sendable, Equatable {
    case watched
    case excluded
    case detected
    case selectedMusicApp
}

struct RecentAudioSource: Sendable, Equatable {
    var bundleIdentifier: String
    var pid: pid_t
    var firstSeenAt: TimeInterval
    var lastSeenAt: TimeInterval
    var status: RecentAudioSourceStatus
}

final class RecentAudioSourceStore: @unchecked Sendable {
    static let shared = RecentAudioSourceStore()

    private let queue = DispatchQueue(label: "com.flowsound.recent-audio-sources")
    private var sourcesByBundleIdentifier: [String: RecentAudioSource] = [:]

    func record(bundleIdentifier: String, pid: pid_t, status: RecentAudioSourceStatus, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        queue.sync {
            var source = self.sourcesByBundleIdentifier[bundleIdentifier] ?? RecentAudioSource(
                bundleIdentifier: bundleIdentifier,
                pid: pid,
                firstSeenAt: now,
                lastSeenAt: now,
                status: status
            )
            source.pid = pid
            source.lastSeenAt = now
            source.status = status
            self.sourcesByBundleIdentifier[bundleIdentifier] = source
            self.pruneLocked(now: now)
        }
    }

    func recentSources(within interval: TimeInterval = 180, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> [RecentAudioSource] {
        queue.sync {
            pruneLocked(now: now, interval: interval)
            return sourcesByBundleIdentifier.values
                .filter { now - $0.lastSeenAt <= interval }
                .sorted { $0.lastSeenAt > $1.lastSeenAt }
        }
    }

    private func pruneLocked(now: TimeInterval, interval: TimeInterval = 180) {
        sourcesByBundleIdentifier = sourcesByBundleIdentifier.filter { _, source in
            now - source.lastSeenAt <= interval
        }
    }
}
