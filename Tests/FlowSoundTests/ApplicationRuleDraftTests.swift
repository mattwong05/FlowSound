import Testing
@testable import FlowSound

@Test func movingAnApplicationOnlyUpdatesTheDraftAndPreservesOtherRules() {
    let original = ApplicationRuleDraft(
        watchedText: "com.apple.Safari\ncom.example.Video",
        excludedText: "com.example.Video\nsystemsoundserverd"
    )
    var draft = original
    draft.add(["com.example.Video"], to: .watched)
    #expect(draft.watched == ["com.apple.Safari", "com.example.Video"])
    #expect(draft.excluded == ["systemsoundserverd"])
    #expect(original.excluded == ["com.example.Video", "systemsoundserverd"])
}

@Test func applicationDraftDeduplicatesAndRejectsInvalidIdentifiers() {
    var draft = ApplicationRuleDraft(watchedText: "com.example.Video", excludedText: "")
    draft.add(["com.example.Video", "invalid", "com.example.Video"], to: .excluded)
    #expect(draft.watched.isEmpty)
    #expect(draft.excluded == ["com.example.Video"])
}

@Test func removingAnExplicitRuleOnlyAffectsItsSelectedList() {
    var draft = ApplicationRuleDraft(watchedText: "com.example.Video\ncom.apple.Safari", excludedText: "com.example.Video\nsystemsoundserverd")
    draft.remove("com.example.Video", from: .watched)
    #expect(draft.watched == ["com.apple.Safari"])
    #expect(draft.excluded == ["com.example.Video", "systemsoundserverd"])
    draft.remove("com.example.Missing", from: .excluded)
    #expect(draft.excluded == ["com.example.Video", "systemsoundserverd"])
}

@Test func deletingTheSelectedMusicRuleDoesNotRemoveItsEffectiveExclusion() {
    var settings = FlowSoundSettings.defaults
    var draft = ApplicationRuleDraft(watchedText: "com.apple.Safari", excludedText: "com.apple.Music\nsystemsoundserverd")
    draft.remove("com.apple.Music", from: .excluded)
    settings.excludedBundleIdentifiers = draft.excluded
    #expect(!draft.excluded.contains("com.apple.Music"))
    let effective = FlowSoundSettings.effectiveExcludedBundleIdentifiers(for: settings, appBundleIdentifier: "com.flowsound.FlowSound")
    #expect(effective.contains("com.apple.Music"))
    #expect(effective.contains("com.flowsound.FlowSound"))
}

@Test func removingTheLastRulesKeepsAnExplicitEmptyDraft() {
    var draft = ApplicationRuleDraft(watchedText: "com.apple.Safari", excludedText: "com.example.Noisy")
    draft.remove("com.apple.Safari", from: .watched)
    draft.remove("com.example.Noisy", from: .excluded)
    #expect(draft.watched.isEmpty)
    #expect(draft.excluded.isEmpty)
    #expect(FlowSoundSettings.validWatchedBundleIdentifiers(draft.watched).isEmpty)
    #expect(FlowSoundSettings.validExcludedBundleIdentifiers(draft.excluded).isEmpty)
}
