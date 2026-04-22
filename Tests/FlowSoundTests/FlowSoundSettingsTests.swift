import Foundation
import Testing
@testable import FlowSound

@Test func bundleIdentifierTextParsingTrimsDeduplicatesAndFiltersInvalidValues() {
    let identifiers = FlowSoundSettings.bundleIdentifiers(
        fromText: """
        com.apple.Safari
        ru.keepcoder.Telegram
        com.apple.Safari
        invalid
        bad identifier
        com.example-player.app;
        """
    )

    #expect(identifiers == [
        "com.apple.Safari",
        "ru.keepcoder.Telegram",
        "com.example-player.app"
    ])
}

@Test func defaultsUseAllNonMusicModeAndCurrentTiming() {
    #expect(FlowSoundSettings.defaults.controlledMusicPlayer == .appleMusic)
    #expect(FlowSoundSettings.defaults.monitoringMode == .allNonMusic)
    #expect(FlowSoundSettings.defaults.activeDuration == 1.0)
    #expect(FlowSoundSettings.defaults.quietDuration == 3.0)
    #expect(FlowSoundSettings.defaults.fadeOutDuration == 2.0)
    #expect(FlowSoundSettings.defaults.fadeInDuration == 2.0)
}

@Test func emptyWatchedBundleIdentifiersFallBackToDefaults() {
    let identifiers = FlowSoundSettings.validWatchedBundleIdentifiers([])

    #expect(identifiers == FlowSoundSettings.defaults.watchedBundleIdentifiers)
}

@Test func defaultExcludedBundleIdentifiersContainAppleMusicAndNotificationServices() {
    #expect(FlowSoundSettings.defaultExcludedBundleIdentifiers.contains("com.apple.Music"))
    #expect(FlowSoundSettings.defaultExcludedBundleIdentifiers.contains("com.apple.usernoted"))
}

@Test func emptyExcludedBundleIdentifiersFallBackToDefaults() {
    let identifiers = FlowSoundSettings.validExcludedBundleIdentifiers([])

    #expect(identifiers == FlowSoundSettings.defaultExcludedBundleIdentifiers)
}

@Test func safariWatchedBundleIdentifierExpandsToWebKitAudioHelpers() {
    let identifiers = FlowSoundSettings.expandedWatchedBundleIdentifiers(["com.apple.Safari"])

    #expect(identifiers.contains("com.apple.Safari"))
    #expect(identifiers.contains("com.apple.WebKit.GPU"))
    #expect(identifiers.contains("com.apple.WebKit.WebContent"))
    #expect(identifiers.contains("com.apple.WebKit.Networking"))
}

@Test func spotifyControlledPlayerAddsSpotifyToEffectiveExclusions() {
    var settings = FlowSoundSettings.defaults
    settings.controlledMusicPlayer = .spotify

    let identifiers = FlowSoundSettings.effectiveExcludedBundleIdentifiers(for: settings, appBundleIdentifier: "com.flowsound.FlowSound")

    #expect(identifiers.contains("com.spotify.client"))
    #expect(identifiers.contains("com.flowsound.FlowSound"))
}

@MainActor
@Test func settingsStorePersistsWatchedBundleIdentifiers() {
    let suiteName = "FlowSoundSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = FlowSoundSettingsStore(defaults: defaults)
    var settings = store.settings
    settings.watchedBundleIdentifiers = ["com.example.VideoApp", "invalid"]
    settings.excludedBundleIdentifiers = ["com.apple.Music", "bad identifier"]
    store.settings = settings

    #expect(store.settings.watchedBundleIdentifiers == ["com.example.VideoApp"])
    #expect(store.settings.excludedBundleIdentifiers == ["com.apple.Music"])
}

@MainActor
@Test func settingsStorePersistsControlledMusicPlayer() {
    let suiteName = "FlowSoundSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = FlowSoundSettingsStore(defaults: defaults)
    var settings = store.settings
    settings.controlledMusicPlayer = .spotify
    store.settings = settings

    #expect(store.settings.controlledMusicPlayer == .spotify)
}

@MainActor
@Test func settingsStorePersistsMonitoringMode() {
    let suiteName = "FlowSoundSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = FlowSoundSettingsStore(defaults: defaults)
    var settings = store.settings
    settings.monitoringMode = .watchedApps
    store.settings = settings

    #expect(store.settings.monitoringMode == .watchedApps)
}

@MainActor
@Test func settingsStoreMigratesOldDefaultTimingValues() {
    let suiteName = "FlowSoundSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(0.5, forKey: "activeDuration")
    defaults.set(5.0, forKey: "quietDuration")
    defaults.set(3.0, forKey: "fadeOutDuration")
    defaults.set(3.0, forKey: "fadeInDuration")

    let store = FlowSoundSettingsStore(defaults: defaults)
    let settings = store.settings

    #expect(settings.activeDuration == 1.0)
    #expect(settings.quietDuration == 3.0)
    #expect(settings.fadeOutDuration == 2.0)
    #expect(settings.fadeInDuration == 2.0)
}

@MainActor
@Test func settingsStorePublishesSanitizedWatchedBundleIdentifiers() {
    let suiteName = "FlowSoundSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = FlowSoundSettingsStore(defaults: defaults)
    var publishedSettings: FlowSoundSettings?
    store.onSettingsChanged = { settings in
        publishedSettings = settings
    }

    var settings = store.settings
    settings.watchedBundleIdentifiers = ["invalid", "com.example.VideoApp"]
    store.settings = settings

    #expect(publishedSettings?.watchedBundleIdentifiers == ["com.example.VideoApp"])
}
