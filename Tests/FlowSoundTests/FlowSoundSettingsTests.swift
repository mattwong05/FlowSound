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

@Test func emptyWatchedBundleIdentifiersFallBackToDefaults() {
    let identifiers = FlowSoundSettings.validWatchedBundleIdentifiers([])

    #expect(identifiers == FlowSoundSettings.defaults.watchedBundleIdentifiers)
}

@MainActor
@Test func settingsStorePersistsWatchedBundleIdentifiers() {
    let suiteName = "FlowSoundSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = FlowSoundSettingsStore(defaults: defaults)
    var settings = store.settings
    settings.watchedBundleIdentifiers = ["com.example.VideoApp", "invalid"]
    store.settings = settings

    #expect(store.settings.watchedBundleIdentifiers == ["com.example.VideoApp"])
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
