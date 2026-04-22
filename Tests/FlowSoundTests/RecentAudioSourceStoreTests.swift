import Foundation
import Testing
@testable import FlowSound

@Test func recentAudioSourceStoreKeepsLatestThreeMinuteSources() {
    let store = RecentAudioSourceStore()
    store.record(bundleIdentifier: "com.example.Old", pid: 100, status: .watched, now: 10)
    store.record(bundleIdentifier: "com.example.New", pid: 200, status: .excluded, now: 200)

    let sources = store.recentSources(within: 180, now: 200)

    #expect(sources.map(\.bundleIdentifier) == ["com.example.New"])
    #expect(sources.first?.status == .excluded)
}

@Test func recentAudioSourceStoreUpdatesExistingBundleIdentifier() {
    let store = RecentAudioSourceStore()
    store.record(bundleIdentifier: "com.example.App", pid: 100, status: .detected, now: 100)
    store.record(bundleIdentifier: "com.example.App", pid: 101, status: .watched, now: 110)

    let sources = store.recentSources(within: 180, now: 110)

    #expect(sources.count == 1)
    #expect(sources.first?.pid == 101)
    #expect(sources.first?.status == .watched)
}
