import Foundation
import Testing
@testable import FlowSound

@MainActor
@Test func bundledProfilesIncludeNeteaseExperimentalProfile() {
    let profile = MusicAdapterProfileStore.bundledProfiles.first { $0.id == "community.netease-cloud-music.menu-tap" }

    #expect(profile?.displayName == "Netease Cloud Music")
    #expect(profile?.supportLevel == .experimental)
    #expect(profile?.playbackStateCapability == .menuState)
    #expect(profile?.volumeControlCapability == .relativeStep)
    #expect(profile?.bundleIdentifiers == ["com.netease.163music"])
}

@MainActor
@Test func profileStoreImportsAndExportsProfiles() throws {
    let suiteName = "MusicAdapterProfileTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = MusicAdapterProfileStore(defaults: defaults)
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let exportURL = directory.appendingPathComponent("profile.json")
    let profile = MusicAdapterProfile(
        id: "community.example",
        displayName: "Example Player",
        supportLevel: .community,
        bundleIdentifiers: ["com.example.player"],
        playbackStateCapability: .menuState,
        volumeControlCapability: .relativeStep,
        permissions: ["Accessibility"],
        notes: "Test profile."
    )

    try store.exportProfile(profile, to: exportURL)
    try store.importProfile(from: exportURL)

    #expect(store.profiles.contains(profile))
}
