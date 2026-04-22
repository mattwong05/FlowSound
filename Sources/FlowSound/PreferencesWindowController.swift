import AppKit

@MainActor
final class PreferencesWindowController {
    private enum Layout {
        static let width: CGFloat = 680
        static let collapsedHeight: CGFloat = 620
        static let expandedHeight: CGFloat = 780
        static let minimumHeight: CGFloat = 520
        static let horizontalInset: CGFloat = 24
        static let verticalInset: CGFloat = 22
        static let contentWidth: CGFloat = 620
    }

    private let settingsStore: FlowSoundSettingsStore
    private var window: NSWindow?
    private var loadedLaunchAtLoginState: Bool?

    private let musicPlayerPopup = NSPopUpButton()
    private let monitoringModePopup = NSPopUpButton()
    private let activeThresholdField = NSTextField()
    private let activeDurationField = NSTextField()
    private let quietDurationField = NSTextField()
    private let fadeOutDurationField = NSTextField()
    private let fadeInDurationField = NSTextField()
    private let showsMenuBarTextCheckbox = NSButton(checkboxWithTitle: FlowSoundStrings.text(.showMenuBarText), target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: FlowSoundStrings.text(.launchAtLogin), target: nil, action: nil)
    private let loginItemStatusLabel = NSTextField(labelWithString: "")
    private let advancedDisclosure = NSButton(title: FlowSoundStrings.text(.advancedToggleShow), target: nil, action: nil)
    private let advancedContainer = NSStackView()
    private let watchedBundleIdentifiersTextView = NSTextView()
    private let excludedBundleIdentifiersTextView = NSTextView()

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

        let rootView = NSView()

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSStackView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.orientation = .vertical
        contentView.alignment = .leading
        contentView.spacing = 14
        contentView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let title = NSTextField(labelWithString: FlowSoundStrings.text(.preferencesTitle))
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        contentView.addArrangedSubview(title)

        contentView.addArrangedSubview(
            makeSection(
                title: FlowSoundStrings.text(.musicPlayer),
                help: FlowSoundStrings.text(.musicPlayerHelp),
                rows: [makeMusicPlayerRow()]
            )
        )
        contentView.addArrangedSubview(
            makeSection(
                title: FlowSoundStrings.text(.audioMonitoring),
                help: FlowSoundStrings.text(.audioMonitoringHelp),
                rows: [makeMonitoringModeRow()]
            )
        )
        contentView.addArrangedSubview(
            makeSection(
                title: FlowSoundStrings.text(.timing),
                help: FlowSoundStrings.text(.timingHelp),
                rows: [
                    formRow(FlowSoundStrings.text(.activeThreshold), activeThresholdField, FlowSoundStrings.text(.activeThresholdHelp)),
                    formRow(FlowSoundStrings.text(.activeDuration), activeDurationField, FlowSoundStrings.text(.activeDurationHelp)),
                    formRow(FlowSoundStrings.text(.quietDuration), quietDurationField, FlowSoundStrings.text(.quietDurationHelp)),
                    formRow(FlowSoundStrings.text(.fadeOut), fadeOutDurationField, FlowSoundStrings.text(.fadeOutHelp)),
                    formRow(FlowSoundStrings.text(.fadeIn), fadeInDurationField, FlowSoundStrings.text(.fadeInHelp))
                ]
            )
        )
        contentView.addArrangedSubview(makeOptionsSection())
        contentView.addArrangedSubview(makeAdvancedSection())

        documentView.addSubview(contentView)
        scrollView.documentView = documentView

        let buttonRow = makeButtonRow()
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(scrollView)
        rootView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: Layout.verticalInset),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.horizontalInset),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.horizontalInset),
            buttonRow.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 14),
            buttonRow.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.horizontalInset),
            buttonRow.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -Layout.horizontalInset),
            buttonRow.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -Layout.verticalInset),

            contentView.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: preferredWindowHeight()),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow.title = FlowSoundStrings.text(.preferencesTitle)
        preferencesWindow.contentView = rootView
        preferencesWindow.minSize = NSSize(width: Layout.width, height: Layout.minimumHeight)
        preferencesWindow.center()
        preferencesWindow.isReleasedWhenClosed = false
        window = preferencesWindow

        populateFields()
        preferencesWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeSection(title: String, help: String, rows: [NSView]) -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        let titleView = NSTextField(labelWithString: title)
        titleView.font = .systemFont(ofSize: 13, weight: .semibold)
        section.addArrangedSubview(titleView)

        let helpView = NSTextField(wrappingLabelWithString: help)
        helpView.textColor = .secondaryLabelColor
        helpView.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        section.addArrangedSubview(helpView)

        for row in rows {
            section.addArrangedSubview(row)
        }

        return section
    }

    private func makeMusicPlayerRow() -> NSStackView {
        musicPlayerPopup.removeAllItems()
        for player in ControlledMusicPlayer.allCases {
            musicPlayerPopup.addItem(withTitle: player.displayName)
            musicPlayerPopup.lastItem?.representedObject = player.rawValue
        }
        musicPlayerPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        return controlRow(FlowSoundStrings.text(.musicPlayer), musicPlayerPopup)
    }

    private func makeMonitoringModeRow() -> NSStackView {
        monitoringModePopup.removeAllItems()
        for mode in AudioMonitoringMode.allCases {
            monitoringModePopup.addItem(withTitle: mode.label)
            monitoringModePopup.lastItem?.representedObject = mode.rawValue
        }
        monitoringModePopup.target = self
        monitoringModePopup.action = #selector(monitoringModeChanged)
        monitoringModePopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        return controlRow(FlowSoundStrings.text(.audioMonitoring), monitoringModePopup)
    }

    private func makeOptionsSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        showsMenuBarTextCheckbox.target = self
        launchAtLoginCheckbox.target = self
        loginItemStatusLabel.textColor = .secondaryLabelColor

        section.addArrangedSubview(showsMenuBarTextCheckbox)
        section.addArrangedSubview(launchAtLoginCheckbox)
        section.addArrangedSubview(loginItemStatusLabel)
        return section
    }

    private func makeAdvancedSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        let title = NSTextField(labelWithString: FlowSoundStrings.text(.advanced))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        section.addArrangedSubview(title)

        let help = NSTextField(wrappingLabelWithString: FlowSoundStrings.text(.advancedHelp))
        help.textColor = .secondaryLabelColor
        help.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        section.addArrangedSubview(help)

        advancedDisclosure.setButtonType(.pushOnPushOff)
        advancedDisclosure.bezelStyle = .disclosure
        advancedDisclosure.state = .off
        advancedDisclosure.target = self
        advancedDisclosure.action = #selector(toggleAdvanced)
        section.addArrangedSubview(advancedDisclosure)

        advancedContainer.orientation = .vertical
        advancedContainer.alignment = .leading
        advancedContainer.spacing = 10
        advancedContainer.isHidden = true
        advancedContainer.addArrangedSubview(makeBundleIdentifierEditor(
            title: FlowSoundStrings.text(.watchedApps),
            help: FlowSoundStrings.text(.watchedAppsHelp),
            textView: watchedBundleIdentifiersTextView,
            height: 96
        ))
        advancedContainer.addArrangedSubview(makeBundleIdentifierEditor(
            title: FlowSoundStrings.text(.excludedApps),
            help: FlowSoundStrings.text(.excludedAppsHelp),
            textView: excludedBundleIdentifiersTextView,
            height: 86
        ))
        section.addArrangedSubview(advancedContainer)

        return section
    }

    private func makeBundleIdentifierEditor(title: String, help: String, textView: NSTextView, height: CGFloat) -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 6

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        section.addArrangedSubview(label)

        let helpView = NSTextField(wrappingLabelWithString: help)
        helpView.textColor = .secondaryLabelColor
        helpView.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        section.addArrangedSubview(helpView)

        configureBundleIdentifierTextView(textView)

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: height).isActive = true
        section.addArrangedSubview(scrollView)
        return section
    }

    private func makeButtonRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        let resetButton = NSButton(title: FlowSoundStrings.text(.resetDefaults), target: self, action: #selector(resetDefaults))
        let loginItemsButton = NSButton(title: FlowSoundStrings.text(.openLoginItems), target: self, action: #selector(openLoginItems))
        let saveButton = NSButton(title: FlowSoundStrings.text(.save), target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        row.addArrangedSubview(resetButton)
        row.addArrangedSubview(loginItemsButton)
        row.addArrangedSubview(saveButton)
        return row
    }

    private func controlRow(_ label: String, _ control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 138).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(control)
        return row
    }

    private func formRow(_ label: String, _ field: NSTextField, _ help: String) -> NSStackView {
        let row = controlRow(label, field)

        field.alignment = .right
        field.placeholderString = "0.0"
        field.toolTip = help
        field.widthAnchor.constraint(equalToConstant: 86).isActive = true

        let helpView = NSTextField(labelWithString: help)
        helpView.textColor = .secondaryLabelColor
        helpView.lineBreakMode = .byTruncatingTail
        helpView.maximumNumberOfLines = 1
        helpView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        row.addArrangedSubview(helpView)
        return row
    }

    private func populateFields() {
        let settings = settingsStore.settings
        selectMusicPlayer(settings.controlledMusicPlayer)
        selectMonitoringMode(settings.monitoringMode)
        activeThresholdField.stringValue = Self.format(settings.activeThreshold)
        activeDurationField.stringValue = Self.format(settings.activeDuration)
        quietDurationField.stringValue = Self.format(settings.quietDuration)
        fadeOutDurationField.stringValue = Self.format(settings.fadeOutDuration)
        fadeInDurationField.stringValue = Self.format(settings.fadeInDuration)
        watchedBundleIdentifiersTextView.string = settings.watchedBundleIdentifiers.joined(separator: "\n")
        excludedBundleIdentifiersTextView.string = settings.excludedBundleIdentifiers.joined(separator: "\n")
        showsMenuBarTextCheckbox.state = settings.showsMenuBarText ? .on : .off
        let launchAtLoginState = LoginItemController.isEnabledOrPendingApproval
        loadedLaunchAtLoginState = launchAtLoginState
        launchAtLoginCheckbox.state = launchAtLoginState ? .on : .off
        loginItemStatusLabel.stringValue = LoginItemController.statusText
        updateBundleIdentifierEditorAvailability()
    }

    @objc private func save() {
        var settings = settingsStore.settings
        settings.controlledMusicPlayer = selectedMusicPlayer()
        settings.monitoringMode = selectedMonitoringMode()
        settings.activeThreshold = clampedDouble(activeThresholdField, fallback: settings.activeThreshold, range: 0.001...1.0)
        settings.activeDuration = clampedDouble(activeDurationField, fallback: settings.activeDuration, range: 0.1...10.0)
        settings.quietDuration = clampedDouble(quietDurationField, fallback: settings.quietDuration, range: 0.1...60.0)
        settings.fadeOutDuration = clampedDouble(fadeOutDurationField, fallback: settings.fadeOutDuration, range: 0.1...30.0)
        settings.fadeInDuration = clampedDouble(fadeInDurationField, fallback: settings.fadeInDuration, range: 0.1...30.0)
        settings.watchedBundleIdentifiers = FlowSoundSettings.validWatchedBundleIdentifiers(
            FlowSoundSettings.bundleIdentifiers(fromText: watchedBundleIdentifiersTextView.string)
        )
        settings.excludedBundleIdentifiers = FlowSoundSettings.validExcludedBundleIdentifiers(
            FlowSoundSettings.bundleIdentifiers(fromText: excludedBundleIdentifiersTextView.string)
        )
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

    private func selectMusicPlayer(_ player: ControlledMusicPlayer) {
        let index = ControlledMusicPlayer.allCases.firstIndex(of: player) ?? 0
        musicPlayerPopup.selectItem(at: index)
    }

    private func selectedMusicPlayer() -> ControlledMusicPlayer {
        guard let rawValue = musicPlayerPopup.selectedItem?.representedObject as? String,
              let player = ControlledMusicPlayer(rawValue: rawValue)
        else {
            return .appleMusic
        }
        return player
    }

    private func selectMonitoringMode(_ mode: AudioMonitoringMode) {
        let index = AudioMonitoringMode.allCases.firstIndex(of: mode) ?? 0
        monitoringModePopup.selectItem(at: index)
    }

    private func selectedMonitoringMode() -> AudioMonitoringMode {
        guard let rawValue = monitoringModePopup.selectedItem?.representedObject as? String,
              let mode = AudioMonitoringMode(rawValue: rawValue)
        else {
            return .allNonMusic
        }
        return mode
    }

    private func updateBundleIdentifierEditorAvailability() {
        let isWatchedAppsMode = selectedMonitoringMode() == .watchedApps
        watchedBundleIdentifiersTextView.isEditable = isWatchedAppsMode
        watchedBundleIdentifiersTextView.textColor = isWatchedAppsMode ? .labelColor : .secondaryLabelColor

        let isExcludedAppsMode = selectedMonitoringMode() == .allNonMusic
        excludedBundleIdentifiersTextView.isEditable = isExcludedAppsMode
        excludedBundleIdentifiersTextView.textColor = isExcludedAppsMode ? .labelColor : .secondaryLabelColor
    }

    @objc private func monitoringModeChanged() {
        updateBundleIdentifierEditorAvailability()
    }

    @objc private func toggleAdvanced() {
        let isExpanded = advancedDisclosure.state == .on
        advancedContainer.isHidden = !isExpanded
        advancedDisclosure.title = FlowSoundStrings.text(isExpanded ? .advancedToggleHide : .advancedToggleShow)
        resizeWindowForAdvancedState()
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    private func preferredWindowHeight() -> CGFloat {
        let preferredHeight = advancedDisclosure.state == .on ? Layout.expandedHeight : Layout.collapsedHeight
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? preferredHeight
        let cappedHeight = min(preferredHeight, visibleHeight - 80)
        return max(Layout.minimumHeight, cappedHeight)
    }

    private func resizeWindowForAdvancedState() {
        guard let window else { return }
        let newContentHeight = preferredWindowHeight()
        let contentRect = NSRect(x: 0, y: 0, width: Layout.width, height: newContentHeight)
        let newFrameSize = window.frameRect(forContentRect: contentRect).size
        var frame = window.frame
        frame.origin.y += frame.height - newFrameSize.height
        frame.size = newFrameSize
        window.setFrame(frame, display: true, animate: true)
    }

    private func configureBundleIdentifierTextView(_ textView: NSTextView) {
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
    }

    private func updateLaunchAtLogin() {
        let requestedState = launchAtLoginCheckbox.state == .on
        guard requestedState != loadedLaunchAtLoginState else {
            loginItemStatusLabel.textColor = .secondaryLabelColor
            loginItemStatusLabel.stringValue = LoginItemController.statusText
            return
        }

        do {
            try LoginItemController.setEnabled(requestedState)
            loadedLaunchAtLoginState = LoginItemController.isEnabledOrPendingApproval
            loginItemStatusLabel.textColor = .secondaryLabelColor
            loginItemStatusLabel.stringValue = LoginItemController.statusText
        } catch {
            loginItemStatusLabel.textColor = .systemRed
            loginItemStatusLabel.stringValue = FlowSoundStrings.text(.automationUnavailable(error.localizedDescription))
        }
    }

    @objc private func openLoginItems() {
        LoginItemController.openSystemSettings()
    }
}
