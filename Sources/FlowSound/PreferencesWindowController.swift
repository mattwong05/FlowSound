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
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch FlowSound at login", target: nil, action: nil)
    private let loginItemStatusLabel = NSTextField(labelWithString: "")

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
        contentView.spacing = 12
        contentView.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)

        let title = NSTextField(labelWithString: "FlowSound Preferences")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        contentView.addArrangedSubview(title)

        contentView.addArrangedSubview(makeForm())

        showsMenuBarTextCheckbox.target = self
        contentView.addArrangedSubview(showsMenuBarTextCheckbox)

        launchAtLoginCheckbox.target = self
        contentView.addArrangedSubview(launchAtLoginCheckbox)

        loginItemStatusLabel.textColor = .secondaryLabelColor
        contentView.addArrangedSubview(loginItemStatusLabel)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        let resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults))
        let loginItemsButton = NSButton(title: "Open Login Items", target: self, action: #selector(openLoginItems))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(resetButton)
        buttonRow.addArrangedSubview(loginItemsButton)
        buttonRow.addArrangedSubview(saveButton)
        contentView.addArrangedSubview(buttonRow)

        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 410),
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

    private func makeForm() -> NSStackView {
        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 8
        form.addArrangedSubview(formRow("Active threshold", activeThresholdField, "RMS threshold. Default: 0.02"))
        form.addArrangedSubview(formRow("Active duration", activeDurationField, "Seconds before ducking. Default: 0.5"))
        form.addArrangedSubview(formRow("Quiet duration", quietDurationField, "Seconds before restoring. Default: 5.0"))
        form.addArrangedSubview(formRow("Fade out", fadeOutDurationField, "Seconds to fade before pause. Default: 3.0"))
        form.addArrangedSubview(formRow("Fade in", fadeInDurationField, "Seconds to restore volume. Default: 3.0"))
        return form
    }

    private func formRow(_ label: String, _ field: NSTextField, _ help: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 130).isActive = true

        field.alignment = .right
        field.placeholderString = "0.0"
        field.toolTip = help
        field.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let helpView = NSTextField(labelWithString: help)
        helpView.textColor = .secondaryLabelColor
        helpView.lineBreakMode = .byTruncatingTail
        helpView.maximumNumberOfLines = 1
        helpView.widthAnchor.constraint(equalToConstant: 330).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(field)
        row.addArrangedSubview(helpView)
        return row
    }

    private func populateFields() {
        let settings = settingsStore.settings
        activeThresholdField.stringValue = Self.format(settings.activeThreshold)
        activeDurationField.stringValue = Self.format(settings.activeDuration)
        quietDurationField.stringValue = Self.format(settings.quietDuration)
        fadeOutDurationField.stringValue = Self.format(settings.fadeOutDuration)
        fadeInDurationField.stringValue = Self.format(settings.fadeInDuration)
        showsMenuBarTextCheckbox.state = settings.showsMenuBarText ? .on : .off
        launchAtLoginCheckbox.state = LoginItemController.isEnabled ? .on : .off
        loginItemStatusLabel.stringValue = LoginItemController.statusText
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
        updateLaunchAtLogin()
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

    private func updateLaunchAtLogin() {
        do {
            try LoginItemController.setEnabled(launchAtLoginCheckbox.state == .on)
            loginItemStatusLabel.textColor = .secondaryLabelColor
            loginItemStatusLabel.stringValue = LoginItemController.statusText
        } catch {
            loginItemStatusLabel.textColor = .systemRed
            loginItemStatusLabel.stringValue = "Could not update launch at login: \(error.localizedDescription)"
        }
    }

    @objc private func openLoginItems() {
        LoginItemController.openSystemSettings()
    }
}
