import Foundation

struct FlowSoundSettings: Sendable, Equatable {
    var watchedBundleIdentifiers: [String]
    var activeThreshold: Double
    var activeDuration: TimeInterval
    var quietDuration: TimeInterval
    var fadeOutDuration: TimeInterval
    var fadeInDuration: TimeInterval
    var showsMenuBarText: Bool

    static let defaults = FlowSoundSettings(
        watchedBundleIdentifiers: [
            "com.apple.Safari",
            "ru.keepcoder.Telegram"
        ],
        activeThreshold: 0.02,
        activeDuration: 0.5,
        quietDuration: 5.0,
        fadeOutDuration: 3.0,
        fadeInDuration: 3.0,
        showsMenuBarText: true
    )
}

@MainActor
final class FlowSoundSettingsStore {
    var onSettingsChanged: ((FlowSoundSettings) -> Void)?

    private let defaults: UserDefaults

    private enum Key {
        static let activeThreshold = "activeThreshold"
        static let activeDuration = "activeDuration"
        static let quietDuration = "quietDuration"
        static let fadeOutDuration = "fadeOutDuration"
        static let fadeInDuration = "fadeInDuration"
        static let showsMenuBarText = "showsMenuBarText"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    var settings: FlowSoundSettings {
        get {
            FlowSoundSettings(
                watchedBundleIdentifiers: FlowSoundSettings.defaults.watchedBundleIdentifiers,
                activeThreshold: defaults.double(forKey: Key.activeThreshold),
                activeDuration: defaults.double(forKey: Key.activeDuration),
                quietDuration: defaults.double(forKey: Key.quietDuration),
                fadeOutDuration: defaults.double(forKey: Key.fadeOutDuration),
                fadeInDuration: defaults.double(forKey: Key.fadeInDuration),
                showsMenuBarText: defaults.bool(forKey: Key.showsMenuBarText)
            )
        }
        set {
            defaults.set(newValue.activeThreshold, forKey: Key.activeThreshold)
            defaults.set(newValue.activeDuration, forKey: Key.activeDuration)
            defaults.set(newValue.quietDuration, forKey: Key.quietDuration)
            defaults.set(newValue.fadeOutDuration, forKey: Key.fadeOutDuration)
            defaults.set(newValue.fadeInDuration, forKey: Key.fadeInDuration)
            defaults.set(newValue.showsMenuBarText, forKey: Key.showsMenuBarText)
            onSettingsChanged?(newValue)
        }
    }

    func reset() {
        settings = .defaults
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.activeThreshold: FlowSoundSettings.defaults.activeThreshold,
            Key.activeDuration: FlowSoundSettings.defaults.activeDuration,
            Key.quietDuration: FlowSoundSettings.defaults.quietDuration,
            Key.fadeOutDuration: FlowSoundSettings.defaults.fadeOutDuration,
            Key.fadeInDuration: FlowSoundSettings.defaults.fadeInDuration,
            Key.showsMenuBarText: FlowSoundSettings.defaults.showsMenuBarText
        ])
    }
}
