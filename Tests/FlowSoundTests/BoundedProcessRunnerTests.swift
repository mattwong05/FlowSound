import Foundation
import Testing
@testable import FlowSound

@Test func commandRunnerReturnsOutputAndErrors() async throws {
    let runner = BoundedProcessRunner()
    let value = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", "return 6 * 7"])
    #expect(value == "42")
    await #expect(throws: (any Error).self) {
        _ = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [])
    }
}

@Test func commandRunnerTimesOutAndAllowsNextCommand() async throws {
    let runner = BoundedProcessRunner()
    let started = ContinuousClock.now
    do {
        _ = try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.05)
        Issue.record("Expected command timeout")
    } catch BoundedProcessRunner.Failure.timedOut {}
    #expect(started.duration(to: .now) < .seconds(2))
    let result = try await runner.run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["ready"])
    #expect(result == "ready")
}

@Test func commandRunnerCancellationStopsOwnedChild() async throws {
    let runner = BoundedProcessRunner()
    let job = Task { try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"]) }
    try await Task.sleep(for: .milliseconds(50))
    job.cancel()
    await #expect(throws: CancellationError.self) { try await job.value }
    let result = try await runner.run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["ready"])
    #expect(result == "ready")
}

@Test func logRotatesAndRetainsBoundedFiles() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("test.log")
    let logger = RotatingDiagnosticLog(url: url, maximumBytes: 200)
    for value in 0..<20 { logger.append("message \(value) " + String(repeating: "x", count: 60)) }
    logger.flush()
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)
    #expect(try Data(contentsOf: url).count <= 200)
    #expect(try Data(contentsOf: url.appendingPathExtension("1")).count <= 200)
    #expect(try String(contentsOf: url, encoding: .utf8).contains("message 19"))
}

@Test func inheritedOutputPipesCannotBlockTheNextCommand() async throws {
    let runner = BoundedProcessRunner()
    let started = ContinuousClock.now
    _ = try await runner.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 1 &"], timeout: 0.2)
    let result = try await runner.run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["ready"])
    #expect(result == "ready")
    #expect(started.duration(to: .now) < .milliseconds(800))
}

@Test func automationHelperRejectsArbitraryScripts() {
    #expect(NeteaseScriptCommand(rawValue: "do shell script \"anything\"") == nil)
    #expect(NeteaseScriptCommand(rawValue: "pause") == .pause)
}
