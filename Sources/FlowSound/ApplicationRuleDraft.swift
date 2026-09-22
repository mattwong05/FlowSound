import Foundation

/// Edits the Preferences draft only. The controller persists it when the user saves.
struct ApplicationRuleDraft: Equatable {
    enum List {
        case watched
        case excluded
    }

    var watched: [String]
    var excluded: [String]

    init(watchedText: String, excludedText: String) {
        watched = FlowSoundSettings.bundleIdentifiers(fromText: watchedText)
        excluded = FlowSoundSettings.bundleIdentifiers(fromText: excludedText)
    }

    mutating func add(_ identifiers: [String], to list: List) {
        let valid = FlowSoundSettings.normalizedBundleIdentifiers(identifiers)
        let moved = Set(valid)
        watched.removeAll { moved.contains($0) }
        excluded.removeAll { moved.contains($0) }
        switch list {
        case .watched:
            watched.append(contentsOf: valid)
        case .excluded:
            excluded.append(contentsOf: valid)
        }
    }

    mutating func remove(_ identifier: String, from list: List) {
        switch list {
        case .watched:
            watched.removeAll { $0 == identifier }
        case .excluded:
            excluded.removeAll { $0 == identifier }
        }
    }
}
