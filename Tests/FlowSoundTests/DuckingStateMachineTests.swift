import Testing
@testable import FlowSound

@Test func stateMachineDucksAndRestores() {
    var stateMachine = DuckingStateMachine()

    #expect(stateMachine.send(.enable) == .listening)
    #expect(stateMachine.send(.watchedAudioStarted) == .ducking)
    #expect(stateMachine.send(.duckCompleted) == .pausedByFlowSound)
    #expect(stateMachine.send(.watchedAudioStopped) == .restoring)
    #expect(stateMachine.send(.restoreCompleted) == .listening)
}

@Test func disablingAlwaysReturnsToDisabled() {
    var stateMachine = DuckingStateMachine()

    _ = stateMachine.send(.enable)
    _ = stateMachine.send(.watchedAudioStarted)

    #expect(stateMachine.send(.disable) == .disabled)
}

@Test func skippedDuckReturnsToListening() {
    var stateMachine = DuckingStateMachine()

    #expect(stateMachine.send(.enable) == .listening)
    #expect(stateMachine.send(.watchedAudioStarted) == .ducking)
    #expect(stateMachine.send(.duckSkipped) == .listening)
}
