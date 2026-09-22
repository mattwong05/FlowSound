import AppKit
import Foundation

protocol MusicControlAdapter: Sendable {
    var descriptor: MusicControlAdapterDescriptor { get }
    var playerName: String { get }
    func playbackState() async throws -> MusicPlaybackState
    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget?
    func restore(_ target: MusicRestoreTarget, settings: FlowSoundSettings) async throws
    func play() async throws
    func pause() async throws
    func instanceIdentifier() async -> Int32?
    func mayRestore(_ target: MusicRestoreTarget) async throws -> Bool
}

extension MusicControlAdapter {
    func instanceIdentifier() async -> Int32? {
        await MainActor.run {
            descriptor.bundleIdentifiers.lazy.flatMap {
                NSRunningApplication.runningApplications(withBundleIdentifier: $0)
            }.first?.processIdentifier
        }
    }

    func mayRestore(_ target: MusicRestoreTarget) async throws -> Bool {
        try await playbackState() == .paused
    }
}

protocol AbsoluteVolumeMusicControlAdapter: MusicControlAdapter {
    func currentVolume() async throws -> Int
    func setVolume(_ volume: Int) async throws
}

struct MusicControlAdapterDescriptor: Sendable, Equatable {
    var id: String
    var displayName: String
    var supportLevel: MusicAdapterSupportLevel
    var bundleIdentifiers: [String]
    var capabilities: MusicAdapterCapabilities
}

enum MusicAdapterSupportLevel: String, Sendable, Equatable {
    case official
    case experimental
    case community
}

struct MusicAdapterCapabilities: Sendable, Equatable {
    var playbackState: MusicPlaybackStateCapability
    var volumeControl: MusicVolumeControlCapability
}

enum MusicPlaybackStateCapability: String, Sendable, Equatable {
    case native
    case menuState
    case audioOutputInference
    case unavailable
}

enum MusicVolumeControlCapability: String, Sendable, Equatable {
    case absolute
    case relativeStep
    case unavailable
}

enum MusicRestoreTarget: Sendable, Equatable {
    case absoluteVolume(Int)
    case relativeSteps(Int)
}

enum MusicPlaybackState: Sendable, Equatable {
    case playing
    case paused
    case stopped
    case unknown(String)
}

enum MusicControlAdapterError: LocalizedError {
    case commandFailed(playerName: String, message: String)
    case invalidVolume(playerName: String, output: String)
    case unsupportedPlayer(String)
    case userIntervened

    var errorDescription: String? {
        switch self {
        case .commandFailed(let playerName, let message):
            "\(playerName) command failed: \(message)"
        case .invalidVolume(let playerName, let output):
            "\(playerName) returned an invalid volume: \(output)"
        case .userIntervened:
            "Player state or volume changed; FlowSound stopped controlling it."
        case .unsupportedPlayer(let playerName):
            "\(playerName) is not supported by this adapter."
        }
    }
}

enum MusicControlAdapterFactory {
    static func adapter(for player: ControlledMusicPlayer) -> any MusicControlAdapter {
        switch player {
        case .appleMusic, .spotify:
            AppleScriptMusicControlAdapter(player: player)
        case .neteaseCloudMusic:
            NeteaseCloudMusicControlAdapter()
        }
    }
}

struct AppleScriptMusicControlAdapter: AbsoluteVolumeMusicControlAdapter {
    let player: ControlledMusicPlayer

    init(player: ControlledMusicPlayer = .appleMusic) {
        self.player = player
    }

    var descriptor: MusicControlAdapterDescriptor {
        MusicControlAdapterDescriptor(
            id: player.rawValue,
            displayName: player.displayName,
            supportLevel: .official,
            bundleIdentifiers: player.bundleIdentifiers,
            capabilities: MusicAdapterCapabilities(
                playbackState: .native,
                volumeControl: .absolute
            )
        )
    }

    var playerName: String {
        player.displayName
    }

    func currentVolume() async throws -> Int {
        let output = try await runAppleScript("""
        if application "\(player.appleScriptApplicationName)" is not running then return "intervened"
        tell application "\(player.appleScriptApplicationName)"
            sound volume
        end tell
        """)
        guard let volume = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw MusicControlAdapterError.invalidVolume(playerName: playerName, output: output)
        }
        return max(0, min(100, volume))
    }

    func setVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        _ = try await runAppleScript("""
        if application "\(player.appleScriptApplicationName)" is not running then return "intervened"
        tell application "\(player.appleScriptApplicationName)"
            set sound volume to \(clampedVolume)
        end tell
        """)
    }

    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget? {
        let playbackState = try await playbackState()
        guard playbackState == .playing else {
            return nil
        }
        let currentVolume = try await currentVolume()
        try await fadeVolume(from: currentVolume, to: 0, duration: settings.fadeOutDuration)
        try Task.checkCancellation()
        guard try await self.playbackState() == .playing, try await self.currentVolume() == 0 else {
            throw MusicControlAdapterError.userIntervened
        }
        try await pause()
        return .absoluteVolume(currentVolume)
    }

    func restore(_ target: MusicRestoreTarget, settings: FlowSoundSettings) async throws {
        guard case .absoluteVolume(let volume) = target else {
            throw MusicControlAdapterError.commandFailed(
                playerName: playerName,
                message: "Unsupported restore target for absolute-volume adapter."
            )
        }
        guard try await mayRestore(target) else { throw MusicControlAdapterError.userIntervened }
        try Task.checkCancellation()
        try await play()
        try Task.checkCancellation()
        try await fadeVolume(from: 0, to: volume, duration: settings.fadeInDuration)
    }

    func mayRestore(_ target: MusicRestoreTarget) async throws -> Bool {
        guard try await playbackState() == .paused else { return false }
        return try await currentVolume() == 0
    }

    func playbackState() async throws -> MusicPlaybackState {
        let output = try await runAppleScript("""
        if application "\(player.appleScriptApplicationName)" is not running then return "stopped"
        tell application "\(player.appleScriptApplicationName)"
            player state as string
        end tell
        """)
        let state = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch state {
        case "playing":
            return .playing
        case "paused":
            return .paused
        case "stopped":
            return .stopped
        default:
            return .unknown(state)
        }
    }

    func play() async throws {
        _ = try await runAppleScript("""
        if application "\(player.appleScriptApplicationName)" is not running then return "intervened"
        tell application "\(player.appleScriptApplicationName)"
            if (player state as string) is not "paused" or sound volume is not 0 then return "intervened"
            play
        end tell
        """)
    }

    func pause() async throws {
        _ = try await runAppleScript("""
        if application "\(player.appleScriptApplicationName)" is not running then return "intervened"
        tell application "\(player.appleScriptApplicationName)"
            if (player state as string) is not "playing" or sound volume is not 0 then return "intervened"
            pause
        end tell
        """)
    }

    private func fadeVolume(from start: Int, to end: Int, duration: TimeInterval) async throws {
        try Task.checkCancellation()
        let steps = max(1, Int(duration / FlowSoundConstants.fadeStepDuration))
        // One child per fade, instead of one process per volume step. Detect user changes
        // before each write and give up ownership instead of overwriting them.
        let result = try await MusicAutomationScript.run("""
        if application "\(player.appleScriptApplicationName)" is not running then return "intervened"
        tell application "\(player.appleScriptApplicationName)"
            set previousVolume to \(start)
            repeat with stepIndex from 1 to \(steps)
                if (player state as string) is not "playing" then return "intervened"
                if (sound volume) is not previousVolume then return "intervened"
                set nextVolume to round (\(start) + (\(end - start) * stepIndex / \(steps)))
                if nextVolume is not previousVolume then set sound volume to nextVolume
                set previousVolume to nextVolume
                delay \(max(0.001, duration / Double(steps)))
            end repeat
        end tell
        return "completed"
        """, timeout: duration + 5)
        try Task.checkCancellation()
        guard result == "completed" else { throw MusicControlAdapterError.userIntervened }
    }

    private func runAppleScript(_ source: String) async throws -> String {
        try Task.checkCancellation()
        let result = try await MusicAutomationScript.run(source)
        try Task.checkCancellation()
        guard result != "intervened" else { throw MusicControlAdapterError.userIntervened }
        return result
    }

}

struct NeteaseCloudMusicControlAdapter: MusicControlAdapter {
    private enum MenuItem {
        static let playPause = 1
        static let increaseVolume = 4
        static let decreaseVolume = 5
    }

    private let processName = "NeteaseMusic"
    private let bundleIdentifier = "com.netease.163music"
    private let silenceThreshold = 0.0008
    private let requiredSilentChecks = 3
    private let maxFadeOutSteps = 24

    var descriptor: MusicControlAdapterDescriptor {
        MusicControlAdapterDescriptor(
            id: ControlledMusicPlayer.neteaseCloudMusic.rawValue,
            displayName: ControlledMusicPlayer.neteaseCloudMusic.displayName,
            supportLevel: .experimental,
            bundleIdentifiers: [bundleIdentifier],
            capabilities: MusicAdapterCapabilities(
                playbackState: .menuState,
                volumeControl: .relativeStep
            )
        )
    }

    var playerName: String {
        descriptor.displayName
    }

    func playbackState() async throws -> MusicPlaybackState {
        let title = try await runMenuCommand(.playbackState)
        return Self.playbackState(forMenuItemTitle: title)
    }

    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget? {
        guard try await playbackState() == .playing else {
            return nil
        }

        let probe = NeteaseAudioOutputProbe(bundleIdentifier: bundleIdentifier)
        defer { probe.stop() }
        try await probe.start()
        let firstSampleDeadline = ContinuousClock.now + .seconds(2)
        while !probe.metrics().isFresh(maxAge: 0.5) {
            guard ContinuousClock.now < firstSampleDeadline else {
                throw MusicControlAdapterError.commandFailed(playerName: playerName, message: "No fresh audio samples from the player.")
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        var lastSampleAt: TimeInterval?
        var steps = 0
        var silentChecks = 0
        for step in 1...maxFadeOutSteps {
            try Task.checkCancellation()
            _ = try await runMenuCommand(.decreaseVolume)
            steps = step
            try await Task.sleep(for: .seconds(max(0.15, settings.fadeOutDuration / Double(maxFadeOutSteps))))
            let metrics = probe.metrics()
            guard metrics.isFresh(maxAge: 0.5), metrics.sampledAt != lastSampleAt else {
                throw MusicControlAdapterError.commandFailed(playerName: playerName, message: "Player audio samples stopped arriving; automatic control stopped.")
            }
            lastSampleAt = metrics.sampledAt
            if metrics.rms < silenceThreshold && metrics.peak < silenceThreshold * 4 {
                silentChecks += 1
            } else {
                silentChecks = 0
            }
            if silentChecks >= requiredSilentChecks {
                break
            }
        }

        try await pause()
        return .relativeSteps(steps)
    }

    func restore(_ target: MusicRestoreTarget, settings: FlowSoundSettings) async throws {
        guard case .relativeSteps(let steps) = target else {
            throw MusicControlAdapterError.commandFailed(
                playerName: playerName,
                message: "Unsupported restore target for relative-step adapter."
            )
        }

        guard try await mayRestore(target) else { throw MusicControlAdapterError.userIntervened }
        try Task.checkCancellation()
        try await play()
        let restoreSteps = Self.restoreStepCount(forFadeOutSteps: steps)
        let stepDelay = max(0.12, settings.fadeInDuration / Double(max(restoreSteps, 1)))
        for _ in 0..<restoreSteps {
            try Task.checkCancellation()
            _ = try await runMenuCommand(.increaseVolume)
            try await Task.sleep(for: .seconds(stepDelay))
        }
    }

    static func restoreStepCount(forFadeOutSteps steps: Int) -> Int {
        steps <= 2 ? steps : max(0, steps - 2)
    }

    static func playbackState(forMenuItemTitle title: String) -> MusicPlaybackState {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedTitle {
        case "pause", "暂停":
            return .playing
        case "play", "播放":
            return .paused
        case "stopped":
            return .stopped
        default:
            return .unknown(title)
        }
    }

    func play() async throws { _ = try await runMenuCommand(.play) }
    func pause() async throws { _ = try await runMenuCommand(.pause) }

    private func runMenuCommand(_ command: NeteaseScriptCommand) async throws -> String {
        do {
            try Task.checkCancellation()
            let result = try await MusicAutomationScript.runNetease(command)
            try Task.checkCancellation()
            guard result != "intervened" else { throw MusicControlAdapterError.userIntervened }
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch MusicControlAdapterError.userIntervened {
            throw MusicControlAdapterError.userIntervened
        } catch {
            throw MusicControlAdapterError.commandFailed(
                playerName: playerName, message: Self.accessibilityHintIfNeeded(error.localizedDescription)
            )
        }
    }

    private static func accessibilityHintIfNeeded(_ message: String) -> String {
        guard message.contains("-1719") || message.localizedCaseInsensitiveContains("assistive access") else {
            return message
        }
        return "\(message) FlowSound needs Accessibility permission to control the Netease Controls menu. If FlowSound is already enabled there, remove it and add the current app build again."
    }
}

/// The helper accepts only these fixed commands, never caller-provided AppleScript.
enum NeteaseScriptCommand: String {
    case playbackState, play, pause, increaseVolume, decreaseVolume

    var source: String {
        let missing = self == .playbackState ? "stopped" : "intervened"
        let action: String
        if self == .playbackState {
            action = "return name of menu item 1 of controlsMenu"
        } else {
            let expected = self == .play ? ["Play", "播放"] : ["Pause", "暂停"]
            let index = self == .increaseVolume ? 4 : (self == .decreaseVolume ? 5 : 1)
            action = """
            set playbackTitle to name of menu item 1 of controlsMenu
            if playbackTitle is not "\(expected[0])" and playbackTitle is not "\(expected[1])" then return "intervened"
            click menu item \(index) of controlsMenu
            return "completed"
            """
        }
        return """
        tell application "System Events"
            if not (exists process "NeteaseMusic") then return "\(missing)"
            tell process "NeteaseMusic"
                set controlsMenu to menu 1 of menu bar item 4 of menu bar 1
                \(action)
            end tell
        end tell
        """
    }
}
