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

    static func bundleIdentifiers(fromText text: String) -> [String] {
        normalizedBundleIdentifiers(
            text.split { character in
                character.isWhitespace || character.isNewline || character == "," || character == ";"
            }
            .map(String.init)
        )
    }

    static func normalizedBundleIdentifiers(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for identifier in identifiers {
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidBundleIdentifier(trimmed), !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            normalized.append(trimmed)
        }

        return normalized
    }

    static func validWatchedBundleIdentifiers(_ identifiers: [String]) -> [String] {
        let normalized = normalizedBundleIdentifiers(identifiers)
        return normalized.isEmpty ? defaults.watchedBundleIdentifiers : normalized
    }

    private static func isValidBundleIdentifier(_ identifier: String) -> Bool {
        guard identifier.contains("."),
              !identifier.hasPrefix("."),
              !identifier.hasSuffix("."),
              !identifier.contains("..")
        else {
            return false
        }

        return identifier.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 97...122:
                true
            default:
                false
            }
        }
    }
}

@MainActor
final class FlowSoundSettingsStore {
    var onSettingsChanged: ((FlowSoundSettings) -> Void)?

    private let defaults: UserDefaults

    private enum Key {
        static let watchedBundleIdentifiers = "watchedBundleIdentifiers"
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
                watchedBundleIdentifiers: FlowSoundSettings.validWatchedBundleIdentifiers(
                    defaults.stringArray(forKey: Key.watchedBundleIdentifiers) ?? FlowSoundSettings.defaults.watchedBundleIdentifiers
                ),
                activeThreshold: defaults.double(forKey: Key.activeThreshold),
                activeDuration: defaults.double(forKey: Key.activeDuration),
                quietDuration: defaults.double(forKey: Key.quietDuration),
                fadeOutDuration: defaults.double(forKey: Key.fadeOutDuration),
                fadeInDuration: defaults.double(forKey: Key.fadeInDuration),
                showsMenuBarText: defaults.bool(forKey: Key.showsMenuBarText)
            )
        }
        set {
            var savedSettings = newValue
            savedSettings.watchedBundleIdentifiers = FlowSoundSettings.validWatchedBundleIdentifiers(newValue.watchedBundleIdentifiers)
            defaults.set(
                savedSettings.watchedBundleIdentifiers,
                forKey: Key.watchedBundleIdentifiers
            )
            defaults.set(savedSettings.activeThreshold, forKey: Key.activeThreshold)
            defaults.set(savedSettings.activeDuration, forKey: Key.activeDuration)
            defaults.set(savedSettings.quietDuration, forKey: Key.quietDuration)
            defaults.set(savedSettings.fadeOutDuration, forKey: Key.fadeOutDuration)
            defaults.set(savedSettings.fadeInDuration, forKey: Key.fadeInDuration)
            defaults.set(savedSettings.showsMenuBarText, forKey: Key.showsMenuBarText)
            onSettingsChanged?(savedSettings)
        }
    }

    func reset() {
        settings = .defaults
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.watchedBundleIdentifiers: FlowSoundSettings.defaults.watchedBundleIdentifiers,
            Key.activeThreshold: FlowSoundSettings.defaults.activeThreshold,
            Key.activeDuration: FlowSoundSettings.defaults.activeDuration,
            Key.quietDuration: FlowSoundSettings.defaults.quietDuration,
            Key.fadeOutDuration: FlowSoundSettings.defaults.fadeOutDuration,
            Key.fadeInDuration: FlowSoundSettings.defaults.fadeInDuration,
            Key.showsMenuBarText: FlowSoundSettings.defaults.showsMenuBarText
        ])
    }
}
