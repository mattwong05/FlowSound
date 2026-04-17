import Foundation

protocol MusicController: Sendable {
    func currentVolume() async throws -> Int
    func playbackState() async throws -> MusicPlaybackState
    func setVolume(_ volume: Int) async throws
    func play() async throws
    func pause() async throws
}

enum MusicPlaybackState: Sendable, Equatable {
    case playing
    case paused
    case stopped
    case unknown(String)
}

enum MusicControllerError: LocalizedError {
    case commandFailed(String)
    case invalidVolume(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            "Apple Music command failed: \(message)"
        case .invalidVolume(let output):
            "Apple Music returned an invalid volume: \(output)"
        }
    }
}

struct AppleScriptMusicController: MusicController {
    func currentVolume() async throws -> Int {
        let output = try await runAppleScript("""
        tell application "Music"
            sound volume
        end tell
        """)
        guard let volume = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw MusicControllerError.invalidVolume(output)
        }
        return max(0, min(100, volume))
    }

    func setVolume(_ volume: Int) async throws {
        let clampedVolume = max(0, min(100, volume))
        _ = try await runAppleScript("""
        tell application "Music"
            set sound volume to \(clampedVolume)
        end tell
        """)
    }

    func playbackState() async throws -> MusicPlaybackState {
        let output = try await runAppleScript("""
        tell application "Music"
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
        tell application "Music"
            play
        end tell
        """)
    }

    func pause() async throws {
        _ = try await runAppleScript("""
        tell application "Music"
            pause
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

            let output = String(
                data: stdout.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            let error = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            guard process.terminationStatus == 0 else {
                throw MusicControllerError.commandFailed(error.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return output
        }.value
    }
}
