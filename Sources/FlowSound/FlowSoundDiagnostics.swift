import Foundation

/// A small, bounded local log. All file IO happens on one utility queue, never on audio/UI queues.
final class RotatingDiagnosticLog: @unchecked Sendable {
    let url: URL
    private let maximumBytes: Int
    private let queue = DispatchQueue(label: "com.flowsound.diagnostics", qos: .utility)
    private let formatter = ISO8601DateFormatter()

    init(url: URL, maximumBytes: Int = 1_048_576) {
        self.url = url
        self.maximumBytes = maximumBytes
    }

    func append(_ message: String) {
        queue.async { [self] in
            do {
                let manager = FileManager.default
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let line = "[\(formatter.string(from: Date()))] \(message.prefix(4096))\n"
                let data = Data(line.utf8)
                let size = (try? manager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
                if size + data.count > maximumBytes, manager.fileExists(atPath: url.path) {
                    let previous = url.appendingPathExtension("1")
                    if manager.fileExists(atPath: previous.path) { try manager.removeItem(at: previous) }
                    try manager.moveItem(at: url, to: previous)
                }
                if !manager.fileExists(atPath: url.path) { try Data().write(to: url) }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // Diagnostics must not interrupt audio control, including full disks.
            }
        }
    }

    func flush() { queue.sync {} }
}

enum FlowSoundDiagnostics {
    private static let logger = RotatingDiagnosticLog(url: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/FlowSound/FlowSound.log"))
    static func log(_ message: String) { logger.append(message) }
    static var logPath: String { logger.url.path }
    static func flush() { logger.flush() }
}
