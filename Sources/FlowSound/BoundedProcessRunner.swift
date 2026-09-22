import Foundation
import Darwin

/// Serial, cancellable local command execution. Blocking process waits stay off Swift's executor.
final class BoundedProcessRunner: @unchecked Sendable {
    static let shared = BoundedProcessRunner()
    private let queue = DispatchQueue(label: "com.flowsound.automation")

    func run(executable: URL, arguments: [String], timeout: TimeInterval = 5) async throws -> String {
        let invocation = Invocation()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        let output = try invocation.run(executable: executable, arguments: arguments, timeout: timeout)
                        continuation.resume(returning: output)
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { invocation.cancel() }
    }

    enum Failure: LocalizedError {
        case timedOut
        case command(String)
        var errorDescription: String? {
            switch self {
            case .timedOut: "Automation timed out. Check the player's permissions and try again."
            case .command(let message): message
            }
        }
    }

    private final class Output: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        private var finishDeadline: ContinuousClock.Instant?
        func finish() { lock.withLock { finishDeadline = .now + .milliseconds(100) } }
        func drain(_ handle: FileHandle) {
            let fd = handle.fileDescriptor
            let flags = fcntl(fd, F_GETFL)
            guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else { return }
            var buffer = [UInt8](repeating: 0, count: 8192)
            while !lock.withLock({ finishDeadline.map { ContinuousClock.now >= $0 } ?? false }) {
                let count = Darwin.read(fd, &buffer, buffer.count)
                if count > 0 {
                    lock.withLock {
                        if data.count < 65536 { data.append(contentsOf: buffer.prefix(min(count, 65536 - data.count))) }
                    }
                } else if count == 0 { return }
                else if errno == EAGAIN || errno == EWOULDBLOCK {
                    if lock.withLock({ finishDeadline != nil }) { return }
                    Thread.sleep(forTimeInterval: 0.005)
                } else if errno != EINTR { return }
            }
        }
        var text: String { lock.withLock { String(decoding: data, as: UTF8.self) } }
    }

    private final class Invocation: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false
        private var timedOut = false

        func cancel(timeout: Bool = false) {
            lock.withLock {
                if timeout, process == nil { return }
                cancelled = true
                timedOut = timeout
                if let process, process.isRunning {
                    // Kill only the child owned by this invocation, while retaining its identity.
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }

        func run(executable: URL, arguments: [String], timeout: TimeInterval) throws -> String {
            let child = Process()
            let stdout = Pipe(), stderr = Pipe()
            let output = Output(), errors = Output()
            child.executableURL = executable
            child.arguments = arguments
            child.standardOutput = stdout
            child.standardError = stderr
            try lock.withLock {
                guard !cancelled else { throw CancellationError() }
                try child.run()
                process = child
            }
            let timer = DispatchWorkItem { [weak self] in self?.cancel(timeout: true) }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + max(0.01, timeout), execute: timer)
            let readers = DispatchGroup()
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                output.drain(stdout.fileHandleForReading)
                readers.leave()
            }
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                errors.drain(stderr.fileHandleForReading)
                readers.leave()
            }
            child.waitUntilExit()
            timer.cancel()
            let result = lock.withLock { () -> (Bool, Bool) in
                process = nil
                return (cancelled, timedOut)
            }
            output.finish()
            errors.finish()
            readers.wait()
            try? stdout.fileHandleForReading.close()
            try? stderr.fileHandleForReading.close()
            if result.1 { throw Failure.timedOut }
            if result.0 { throw CancellationError() }
            guard child.terminationStatus == 0 else {
                throw Failure.command(errors.text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

/// Uses FlowSound's executable for helper automation; signed-install TCC attribution
/// still needs runtime acceptance testing.
/// The helper executes on its main thread; the menu bar process remains responsive.
enum MusicAutomationScript {
    static let helperArgument = "--flowsound-automation"

    static func run(_ source: String, timeout: TimeInterval = 5) async throws -> String {
        try await BoundedProcessRunner.shared.run(
            executable: URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", source], timeout: timeout
        )
    }

    static func runNetease(_ command: NeteaseScriptCommand) async throws -> String {
        guard let executable = Bundle.main.executableURL else { throw Failure.missingExecutable }
        return try await BoundedProcessRunner.shared.run(
            executable: executable, arguments: [helperArgument, command.rawValue]
        )
    }

    private enum Failure: Error { case missingExecutable }
}
