import Foundation

enum AudioMonitoringMode: String, Sendable, Equatable, CaseIterable {
    case allNonMusic
    case watchedApps

    var label: String {
        switch self {
        case .allNonMusic:
            FlowSoundStrings.text(.allNonMusic)
        case .watchedApps:
            FlowSoundStrings.text(.watchedApps)
        }
    }
}

enum ControlledMusicPlayer: String, Sendable, Equatable, CaseIterable {
    case appleMusic
    case spotify

    var displayName: String {
        switch self {
        case .appleMusic:
            "Apple Music"
        case .spotify:
            "Spotify"
        }
    }

    var appleScriptApplicationName: String {
        switch self {
        case .appleMusic:
            "Music"
        case .spotify:
            "Spotify"
        }
    }

    var bundleIdentifiers: [String] {
        switch self {
        case .appleMusic:
            ["com.apple.Music", "com.apple.iTunes"]
        case .spotify:
            ["com.spotify.client"]
        }
    }
}

struct FlowSoundSettings: Sendable, Equatable {
    var controlledMusicPlayer: ControlledMusicPlayer
    var monitoringMode: AudioMonitoringMode
    var watchedBundleIdentifiers: [String]
    var excludedBundleIdentifiers: [String]
    var activeThreshold: Double
    var activeDuration: TimeInterval
    var quietDuration: TimeInterval
    var fadeOutDuration: TimeInterval
    var fadeInDuration: TimeInterval
    var showsMenuBarText: Bool

    static let defaults = FlowSoundSettings(
        controlledMusicPlayer: .appleMusic,
        monitoringMode: .allNonMusic,
        watchedBundleIdentifiers: [
            "com.apple.Safari",
            "ru.keepcoder.Telegram"
        ],
        excludedBundleIdentifiers: [
            "com.apple.Music",
            "com.apple.iTunes",
            "com.flowsound.FlowSound",
            "com.apple.usernoted",
            "com.apple.notificationcenterui"
        ],
        activeThreshold: 0.02,
        activeDuration: 1.0,
        quietDuration: 3.0,
        fadeOutDuration: 2.0,
        fadeInDuration: 2.0,
        showsMenuBarText: true
    )

    static let safariAudioBundleIdentifiers = [
        "com.apple.Safari",
        "com.apple.WebKit.GPU",
        "com.apple.WebKit.WebContent",
        "com.apple.WebKit.Networking",
        "com.apple.SafariPlatformSupport.Helper"
    ]

    static var defaultExcludedBundleIdentifiers: [String] {
        defaults.excludedBundleIdentifiers
    }

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

    static func validExcludedBundleIdentifiers(_ identifiers: [String]) -> [String] {
        let normalized = normalizedBundleIdentifiers(identifiers)
        return normalized.isEmpty ? defaults.excludedBundleIdentifiers : normalized
    }

    static func effectiveExcludedBundleIdentifiers(for settings: FlowSoundSettings, appBundleIdentifier: String? = Bundle.main.bundleIdentifier) -> [String] {
        var identifiers = validExcludedBundleIdentifiers(settings.excludedBundleIdentifiers)
        identifiers.append(contentsOf: settings.controlledMusicPlayer.bundleIdentifiers)
        if let appBundleIdentifier {
            identifiers.append(appBundleIdentifier)
        }
        return normalizedBundleIdentifiers(identifiers)
    }

    static func expandedWatchedBundleIdentifiers(_ identifiers: [String]) -> [String] {
        let validIdentifiers = validWatchedBundleIdentifiers(identifiers)
        var expanded: [String] = []

        for identifier in validIdentifiers {
            if identifier == "com.apple.Safari" {
                expanded.append(contentsOf: safariAudioBundleIdentifiers)
            } else {
                expanded.append(identifier)
            }
        }

        return normalizedBundleIdentifiers(expanded)
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
        static let settingsSchemaVersion = "settingsSchemaVersion"
        static let controlledMusicPlayer = "controlledMusicPlayer"
        static let monitoringMode = "monitoringMode"
        static let watchedBundleIdentifiers = "watchedBundleIdentifiers"
        static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
        static let activeThreshold = "activeThreshold"
        static let activeDuration = "activeDuration"
        static let quietDuration = "quietDuration"
        static let fadeOutDuration = "fadeOutDuration"
        static let fadeInDuration = "fadeInDuration"
        static let showsMenuBarText = "showsMenuBarText"
    }

    private enum Schema {
        static let currentVersion = 1
        static let previousActiveDuration = 0.5
        static let previousQuietDuration = 5.0
        static let previousFadeOutDuration = 3.0
        static let previousFadeInDuration = 3.0
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
        migrateDefaultsIfNeeded()
    }

    var settings: FlowSoundSettings {
        get {
            FlowSoundSettings(
                controlledMusicPlayer: ControlledMusicPlayer(rawValue: defaults.string(forKey: Key.controlledMusicPlayer) ?? "") ?? FlowSoundSettings.defaults.controlledMusicPlayer,
                monitoringMode: AudioMonitoringMode(rawValue: defaults.string(forKey: Key.monitoringMode) ?? "") ?? FlowSoundSettings.defaults.monitoringMode,
                watchedBundleIdentifiers: FlowSoundSettings.validWatchedBundleIdentifiers(
                    defaults.stringArray(forKey: Key.watchedBundleIdentifiers) ?? FlowSoundSettings.defaults.watchedBundleIdentifiers
                ),
                excludedBundleIdentifiers: FlowSoundSettings.validExcludedBundleIdentifiers(
                    defaults.stringArray(forKey: Key.excludedBundleIdentifiers) ?? FlowSoundSettings.defaults.excludedBundleIdentifiers
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
            savedSettings.excludedBundleIdentifiers = FlowSoundSettings.validExcludedBundleIdentifiers(newValue.excludedBundleIdentifiers)
            defaults.set(savedSettings.controlledMusicPlayer.rawValue, forKey: Key.controlledMusicPlayer)
            defaults.set(savedSettings.monitoringMode.rawValue, forKey: Key.monitoringMode)
            defaults.set(
                savedSettings.watchedBundleIdentifiers,
                forKey: Key.watchedBundleIdentifiers
            )
            defaults.set(
                savedSettings.excludedBundleIdentifiers,
                forKey: Key.excludedBundleIdentifiers
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
            Key.controlledMusicPlayer: FlowSoundSettings.defaults.controlledMusicPlayer.rawValue,
            Key.monitoringMode: FlowSoundSettings.defaults.monitoringMode.rawValue,
            Key.watchedBundleIdentifiers: FlowSoundSettings.defaults.watchedBundleIdentifiers,
            Key.excludedBundleIdentifiers: FlowSoundSettings.defaults.excludedBundleIdentifiers,
            Key.activeThreshold: FlowSoundSettings.defaults.activeThreshold,
            Key.activeDuration: FlowSoundSettings.defaults.activeDuration,
            Key.quietDuration: FlowSoundSettings.defaults.quietDuration,
            Key.fadeOutDuration: FlowSoundSettings.defaults.fadeOutDuration,
            Key.fadeInDuration: FlowSoundSettings.defaults.fadeInDuration,
            Key.showsMenuBarText: FlowSoundSettings.defaults.showsMenuBarText
        ])
    }

    private func migrateDefaultsIfNeeded() {
        guard defaults.integer(forKey: Key.settingsSchemaVersion) < Schema.currentVersion else { return }

        replaceIfOldDefault(
            key: Key.activeDuration,
            oldValue: Schema.previousActiveDuration,
            newValue: FlowSoundSettings.defaults.activeDuration
        )
        replaceIfOldDefault(
            key: Key.quietDuration,
            oldValue: Schema.previousQuietDuration,
            newValue: FlowSoundSettings.defaults.quietDuration
        )
        replaceIfOldDefault(
            key: Key.fadeOutDuration,
            oldValue: Schema.previousFadeOutDuration,
            newValue: FlowSoundSettings.defaults.fadeOutDuration
        )
        replaceIfOldDefault(
            key: Key.fadeInDuration,
            oldValue: Schema.previousFadeInDuration,
            newValue: FlowSoundSettings.defaults.fadeInDuration
        )
        defaults.set(Schema.currentVersion, forKey: Key.settingsSchemaVersion)
    }

    private func replaceIfOldDefault(key: String, oldValue: Double, newValue: Double) {
        guard defaults.object(forKey: key) != nil,
              abs(defaults.double(forKey: key) - oldValue) < 0.0001
        else {
            return
        }
        defaults.set(newValue, forKey: key)
    }
}
