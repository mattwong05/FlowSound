import Foundation

protocol MusicControlAdapter: Sendable {
    var descriptor: MusicControlAdapterDescriptor { get }
    var playerName: String { get }
    func playbackState() async throws -> MusicPlaybackState
    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget?
    func restore(_ target: MusicRestoreTarget, settings: FlowSoundSettings) async throws
    func play() async throws
    func pause() async throws
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

    var errorDescription: String? {
        switch self {
        case .commandFailed(let playerName, let message):
            "\(playerName) command failed: \(message)"
        case .invalidVolume(let playerName, let output):
            "\(playerName) returned an invalid volume: \(output)"
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
        try await play()
        try await fadeVolume(from: 0, to: volume, duration: settings.fadeInDuration)
    }

    func playbackState() async throws -> MusicPlaybackState {
        let output = try await runAppleScript("""
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
        tell application "\(player.appleScriptApplicationName)"
            play
        end tell
        """)
    }

    func pause() async throws {
        _ = try await runAppleScript("""
        tell application "\(player.appleScriptApplicationName)"
            pause
        end tell
        """)
    }

    private func fadeVolume(from start: Int, to end: Int, duration: TimeInterval) async throws {
        let steps = max(1, Int(duration / FlowSoundConstants.fadeStepDuration))
        for step in 0...steps {
            try Task.checkCancellation()
            let progress = Double(step) / Double(steps)
            let volume = Int(round(Double(start) + (Double(end - start) * progress)))
            try await setVolume(volume)
            try await Task.sleep(for: .seconds(FlowSoundConstants.fadeStepDuration))
        }
    }

    private func runAppleScript(_ source: String) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            let output = String(
                data: stdout.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            let error = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            guard process.terminationStatus == 0 else {
                throw MusicControlAdapterError.commandFailed(
                    playerName: playerName,
                    message: error.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return output
        }.value
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
        let title = try await menuItemTitle(MenuItem.playPause)
        switch title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pause":
            return .playing
        case "play":
            return .paused
        default:
            return .unknown(title)
        }
    }

    func duck(settings: FlowSoundSettings) async throws -> MusicRestoreTarget? {
        guard try await playbackState() == .playing else {
            return nil
        }

        let probe = NeteaseAudioOutputProbe(bundleIdentifier: bundleIdentifier)
        try await probe.start()
        defer { probe.stop() }

        var steps = 0
        var silentChecks = 0
        for step in 1...maxFadeOutSteps {
            try Task.checkCancellation()
            try await clickControlMenuItem(MenuItem.decreaseVolume)
            steps = step
            try await Task.sleep(for: .seconds(max(0.15, settings.fadeOutDuration / Double(maxFadeOutSteps))))
            let metrics = probe.metrics()
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

        try await play()
        let restoreSteps = Self.restoreStepCount(forFadeOutSteps: steps)
        let stepDelay = max(0.12, settings.fadeInDuration / Double(max(restoreSteps, 1)))
        for _ in 0..<restoreSteps {
            try Task.checkCancellation()
            try await clickControlMenuItem(MenuItem.increaseVolume)
            try await Task.sleep(for: .seconds(stepDelay))
        }
    }

    static func restoreStepCount(forFadeOutSteps steps: Int) -> Int {
        steps <= 2 ? steps : max(0, steps - 2)
    }

    func play() async throws {
        if try await playbackState() != .playing {
            try await clickControlMenuItem(MenuItem.playPause)
        }
    }

    func pause() async throws {
        if try await playbackState() == .playing {
            try await clickControlMenuItem(MenuItem.playPause)
        }
    }

    private func menuItemTitle(_ index: Int) async throws -> String {
        try await runAppleScript("""
        tell application "System Events" to tell process "\(processName)"
            get name of menu item \(index) of menu 1 of menu bar item 4 of menu bar 1
        end tell
        """)
    }

    private func clickControlMenuItem(_ index: Int) async throws {
        _ = try await runAppleScript("""
        tell application "System Events" to tell process "\(processName)"
            click menu item \(index) of menu 1 of menu bar item 4 of menu bar 1
        end tell
        """)
    }

    private func runAppleScript(_ source: String) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                throw MusicControlAdapterError.commandFailed(
                    playerName: playerName,
                    message: error.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}
