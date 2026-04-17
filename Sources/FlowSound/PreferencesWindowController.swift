import AppKit

@MainActor
final class PreferencesWindowController {
    private let settingsStore: FlowSoundSettingsStore
    private var window: NSWindow?

    private let activeThresholdField = NSTextField()
    private let activeDurationField = NSTextField()
    private let quietDurationField = NSTextField()
    private let fadeOutDurationField = NSTextField()
    private let fadeInDurationField = NSTextField()
    private let showsMenuBarTextCheckbox = NSButton(checkboxWithTitle: "Show FlowSound text in the menu bar", target: nil, action: nil)

    init(settingsStore: FlowSoundSettingsStore) {
        self.settingsStore = settingsStore
    }

    func show() {
        if let window {
            populateFields()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = NSStackView()
        contentView.orientation = .vertical
        contentView.alignment = .leading
        contentView.spacing = 14
        contentView.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)

        let title = NSTextField(labelWithString: "FlowSound Preferences")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        contentView.addArrangedSubview(title)

        let form = NSGridView(views: [
            formRow("Active threshold", activeThresholdField, "RMS threshold. Default: 0.02"),
            formRow("Active duration", activeDurationField, "Seconds before ducking. Default: 0.5"),
            formRow("Quiet duration", quietDurationField, "Seconds before restoring. Default: 5.0"),
            formRow("Fade out", fadeOutDurationField, "Seconds to fade before pause. Default: 3.0"),
            formRow("Fade in", fadeInDurationField, "Seconds to restore volume. Default: 3.0")
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 90
        form.rowSpacing = 10
        form.columnSpacing = 10
        contentView.addArrangedSubview(form)

        showsMenuBarTextCheckbox.target = self
        contentView.addArrangedSubview(showsMenuBarTextCheckbox)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        let resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(resetButton)
        buttonRow.addArrangedSubview(saveButton)
        contentView.addArrangedSubview(buttonRow)

        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow.title = "FlowSound Preferences"
        preferencesWindow.contentView = contentView
        preferencesWindow.center()
        preferencesWindow.isReleasedWhenClosed = false
        window = preferencesWindow

        populateFields()
        preferencesWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func formRow(_ label: String, _ field: NSTextField, _ help: String) -> [NSView] {
        let labelView = NSTextField(labelWithString: label)
        field.alignment = .right
        field.placeholderString = "0.0"
        field.toolTip = help
        let helpView = NSTextField(labelWithString: help)
        helpView.textColor = .secondaryLabelColor
        return [labelView, field, helpView]
    }

    private func populateFields() {
        let settings = settingsStore.settings
        activeThresholdField.stringValue = Self.format(settings.activeThreshold)
        activeDurationField.stringValue = Self.format(settings.activeDuration)
        quietDurationField.stringValue = Self.format(settings.quietDuration)
        fadeOutDurationField.stringValue = Self.format(settings.fadeOutDuration)
        fadeInDurationField.stringValue = Self.format(settings.fadeInDuration)
        showsMenuBarTextCheckbox.state = settings.showsMenuBarText ? .on : .off
    }

    @objc private func save() {
        var settings = settingsStore.settings
        settings.activeThreshold = clampedDouble(activeThresholdField, fallback: settings.activeThreshold, range: 0.001...1.0)
        settings.activeDuration = clampedDouble(activeDurationField, fallback: settings.activeDuration, range: 0.1...10.0)
        settings.quietDuration = clampedDouble(quietDurationField, fallback: settings.quietDuration, range: 0.1...60.0)
        settings.fadeOutDuration = clampedDouble(fadeOutDurationField, fallback: settings.fadeOutDuration, range: 0.1...30.0)
        settings.fadeInDuration = clampedDouble(fadeInDurationField, fallback: settings.fadeInDuration, range: 0.1...30.0)
        settings.showsMenuBarText = showsMenuBarTextCheckbox.state == .on
        settingsStore.settings = settings
        populateFields()
    }

    @objc private func resetDefaults() {
        settingsStore.reset()
        populateFields()
    }

    private func clampedDouble(_ field: NSTextField, fallback: Double, range: ClosedRange<Double>) -> Double {
        guard let value = Double(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return fallback
        }
        return min(range.upperBound, max(range.lowerBound, value))
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3g", value)
    }
}
