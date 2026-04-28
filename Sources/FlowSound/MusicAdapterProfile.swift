import Foundation

struct MusicAdapterProfile: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var supportLevel: MusicAdapterSupportLevel
    var bundleIdentifiers: [String]
    var playbackStateCapability: MusicPlaybackStateCapability
    var volumeControlCapability: MusicVolumeControlCapability
    var permissions: [String]
    var notes: String
}

extension MusicAdapterSupportLevel: Codable {}
extension MusicPlaybackStateCapability: Codable {}
extension MusicVolumeControlCapability: Codable {}

enum MusicAdapterProfileError: LocalizedError {
    case invalidProfile(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfile(let message):
            "Invalid adapter profile: \(message)"
        }
    }
}

@MainActor
final class MusicAdapterProfileStore {
    static let shared = MusicAdapterProfileStore()

    private let defaults: UserDefaults
    private let key = "communityAdapterProfiles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var profiles: [MusicAdapterProfile] {
        get {
            let savedProfiles = (defaults.data(forKey: key)).flatMap { data in
                try? JSONDecoder().decode([MusicAdapterProfile].self, from: data)
            } ?? []
            return Self.bundledProfiles + savedProfiles
        }
        set {
            let customProfiles = newValue.filter { profile in
                !Self.bundledProfiles.contains { $0.id == profile.id }
            }
            if let data = try? JSONEncoder().encode(customProfiles) {
                defaults.set(data, forKey: key)
            }
        }
    }

    func importProfile(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let profile = try JSONDecoder().decode(MusicAdapterProfile.self, from: data)
        try validate(profile)
        var currentProfiles = profiles.filter { $0.id != profile.id }
        currentProfiles.append(profile)
        profiles = currentProfiles
    }

    func exportProfile(_ profile: MusicAdapterProfile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
    }

    private func validate(_ profile: MusicAdapterProfile) throws {
        guard !profile.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MusicAdapterProfileError.invalidProfile("missing id")
        }
        guard !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MusicAdapterProfileError.invalidProfile("missing displayName")
        }
        guard !profile.bundleIdentifiers.isEmpty else {
            throw MusicAdapterProfileError.invalidProfile("missing bundleIdentifiers")
        }
    }

    static let bundledProfiles: [MusicAdapterProfile] = [
        MusicAdapterProfile(
            id: "community.netease-cloud-music.menu-tap",
            displayName: "Netease Cloud Music",
            supportLevel: .experimental,
            bundleIdentifiers: ["com.netease.163music"],
            playbackStateCapability: .menuState,
            volumeControlCapability: .relativeStep,
            permissions: ["Automation", "Accessibility", "System Audio Capture"],
            notes: "Uses English or Simplified Chinese Controls menu titles for play/pause and relative volume steps. Uses Core Audio output feedback only to confirm fade-out silence."
        )
    ]
}
