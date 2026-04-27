import AppKit

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class PreferencesWindowController {
    private enum Layout {
        static let width: CGFloat = 720
        static let defaultHeight: CGFloat = 640
        static let minimumHeight: CGFloat = 420
        static let verticalChrome: CGFloat = 132
        static let generalContentHeight: CGFloat = 560
        static let monitoringContentHeight: CGFloat = 520
        static let toolsContentHeight: CGFloat = 600
        static let contentWidth: CGFloat = 640
        static let labelWidth: CGFloat = 140
        static let fieldWidth: CGFloat = 86
        static let tabWidth: CGFloat = 116
    }

    private enum PreferencesTab: Int, CaseIterable {
        case general
        case monitoring
        case tools

        var title: String {
            switch self {
            case .general:
                FlowSoundStrings.text(.generalTab)
            case .monitoring:
                FlowSoundStrings.text(.monitoringTab)
            case .tools:
                FlowSoundStrings.text(.toolsTab)
            }
        }

        var preferredContentHeight: CGFloat {
            switch self {
            case .general:
                Layout.generalContentHeight
            case .monitoring:
                Layout.monitoringContentHeight
            case .tools:
                Layout.toolsContentHeight
            }
        }
    }

    private let settingsStore: FlowSoundSettingsStore
    private let diagnosticsWindowController = StartupWindowController()
    private var window: NSWindow?
    private var loadedLaunchAtLoginState: Bool?
    private var selectedTab: PreferencesTab = .general
    private let tabControl = NSSegmentedControl()
    private let contentContainer = NSView()
    private var contentHeightConstraint: NSLayoutConstraint?
    private var tabContentViews: [PreferencesTab: NSView] = [:]
    private var fixedWidthViews: Set<ObjectIdentifier> = []

    private let languagePopup = NSPopUpButton()
    private let musicPlayerPopup = NSPopUpButton()
    private let monitoringModePopup = NSPopUpButton()
    private let activeThresholdField = NSTextField()
    private let activeDurationField = NSTextField()
    private let quietDurationField = NSTextField()
    private let fadeOutDurationField = NSTextField()
    private let fadeInDurationField = NSTextField()
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: FlowSoundStrings.text(.launchAtLogin), target: nil, action: nil)
    private let loginItemStatusLabel = NSTextField(labelWithString: "")
    private let watchedBundleIdentifiersTextView = NSTextView()
    private let excludedBundleIdentifiersTextView = NSTextView()
    private let recentSourcesStack = NSStackView()
    private let recentSourcesDocumentView = FlippedDocumentView()
    private let adapterProfilesStack = NSStackView()

    init(settingsStore: FlowSoundSettingsStore) {
        self.settingsStore = settingsStore
    }

    func show() {
        if let window {
            populateFields()
            refreshRecentAudioSources()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        resetReusableViewsForNewWindow()
        let rootView = NSView()
        configureTabControl()

        let buttonRow = makeButtonRow()
        tabControl.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(tabControl)
        rootView.addSubview(contentContainer)
        rootView.addSubview(buttonRow)
        contentHeightConstraint = contentContainer.heightAnchor.constraint(equalToConstant: selectedTab.preferredContentHeight)
        contentHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            tabControl.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 18),
            tabControl.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),

            contentContainer.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: 16),
            contentContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),

            buttonRow.topAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: 14),
            buttonRow.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            buttonRow.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -20),
            buttonRow.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -18)
        ])

        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.defaultHeight),
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

        PreferencesTab.allCases.forEach { _ = contentView(for: $0) }
        showSelectedTab(adjustWindow: false)
        populateFields()
        refreshRecentAudioSources()
        adjustWindowHeightForSelectedTab()
        preferencesWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureTabControl() {
        tabControl.segmentCount = PreferencesTab.allCases.count
        tabControl.trackingMode = .selectOne
        tabControl.target = self
        tabControl.action = #selector(tabChanged)

        for tab in PreferencesTab.allCases {
            tabControl.setLabel(tab.title, forSegment: tab.rawValue)
            tabControl.setWidth(Layout.tabWidth, forSegment: tab.rawValue)
        }
        tabControl.selectedSegment = selectedTab.rawValue
    }

    @objc private func tabChanged() {
        guard let tab = PreferencesTab(rawValue: tabControl.selectedSegment) else {
            return
        }
        selectedTab = tab
        showSelectedTab(adjustWindow: true)
        refreshRecentAudioSources()
    }

    private func showSelectedTab(adjustWindow: Bool) {
        for (tab, view) in tabContentViews {
            view.isHidden = tab != selectedTab
        }

        if adjustWindow {
            adjustWindowHeightForSelectedTab()
        }
    }

    private func contentView(for tab: PreferencesTab) -> NSView {
        if let view = tabContentViews[tab] {
            return view
        }

        let view: NSView
        switch tab {
        case .general:
            view = makeTabScrollView(makeGeneralTab(), height: tab.preferredContentHeight)
        case .monitoring:
            view = makeTabScrollView(makeMonitoringTab(), height: tab.preferredContentHeight)
        case .tools:
            view = makeTabScrollView(makeToolsTab(), height: tab.preferredContentHeight)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        view.isHidden = tab != selectedTab
        tabContentViews[tab] = view
        return view
    }

    private func makeTabScrollView(_ content: NSView, height: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let documentView = FlippedDocumentView(frame: NSRect(x: 0, y: 0, width: Layout.contentWidth, height: height))
        content.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(content)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 2),
            content.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor, constant: -2),
            content.widthAnchor.constraint(equalToConstant: Layout.contentWidth)
        ])

        return scrollView
    }

    private func adjustWindowHeightForSelectedTab() {
        guard let window else {
            return
        }

        let visibleContentHeight = selectedTab.preferredContentHeight
        contentHeightConstraint?.constant = visibleContentHeight

        let targetContentHeight = Layout.verticalChrome + visibleContentHeight
        let screenHeight = window.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? targetContentHeight
        let cappedContentHeight = min(targetContentHeight, screenHeight - 80)

        var frame = window.frame
        let newHeight = max(Layout.minimumHeight, cappedContentHeight)
        let delta = newHeight - frame.height
        frame.origin.y -= delta
        frame.size.height = newHeight
        window.setFrame(frame, display: true, animate: false)
    }

    private func makeGeneralTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.generalTab),
            help: FlowSoundStrings.text(.languageHelp),
            rows: [
                makeLanguageRow(),
                makeMusicPlayerRow()
            ]
        ))
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.experimentalAdapters),
            help: "\(FlowSoundStrings.text(.neteaseAccessHelp))\n\(FlowSoundStrings.text(.neteaseVolumeHelp))",
            rows: [makeAccessibilitySettingsRow()]
        ))
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.timing),
            help: FlowSoundStrings.text(.timingHelp),
            rows: [
                formRow(FlowSoundStrings.text(.activeThreshold), activeThresholdField, FlowSoundStrings.text(.activeThresholdHelp)),
                formRow(FlowSoundStrings.text(.activeDuration), activeDurationField, FlowSoundStrings.text(.activeDurationHelp)),
                formRow(FlowSoundStrings.text(.quietDuration), quietDurationField, FlowSoundStrings.text(.quietDurationHelp)),
                formRow(FlowSoundStrings.text(.fadeOut), fadeOutDurationField, FlowSoundStrings.text(.fadeOutHelp)),
                formRow(FlowSoundStrings.text(.fadeIn), fadeInDurationField, FlowSoundStrings.text(.fadeInHelp))
            ]
        ))
        content.addArrangedSubview(makeLaunchSection())
        return content
    }

    private func makeMonitoringTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.audioMonitoring),
            help: FlowSoundStrings.text(.audioMonitoringHelp),
            rows: [makeMonitoringModeRow()]
        ))
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.advanced),
            help: FlowSoundStrings.text(.watchedAndExcludedHelp),
            rows: [
                makeBundleIdentifierEditor(
                    title: FlowSoundStrings.text(.watchedApps),
                    help: FlowSoundStrings.text(.watchedAppsHelp),
                    textView: watchedBundleIdentifiersTextView,
                    height: 130
                ),
                makeBundleIdentifierEditor(
                    title: FlowSoundStrings.text(.excludedApps),
                    help: FlowSoundStrings.text(.excludedAppsHelp),
                    textView: excludedBundleIdentifiersTextView,
                    height: 110
                )
            ]
        ))
        return content
    }

    private func makeToolsTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.recentAudioSources),
            help: FlowSoundStrings.text(.recentAudioSourcesHelp),
            rows: [
                makeRecentSourcesHeader(),
                makeRecentSourcesList()
            ]
        ))
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.toolsDiagnostics),
            help: FlowSoundStrings.text(.toolsDiagnosticsHelp),
            rows: [makeDiagnosticsRow()]
        ))
        content.addArrangedSubview(makeSection(
            title: FlowSoundStrings.text(.adapterProfiles),
            help: FlowSoundStrings.text(.adapterProfilesHelp),
            rows: [
                makeAdapterProfileActionsRow(),
                makeAdapterProfilesList()
            ]
        ))
        return content
    }

    private func makeTabStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        return stack
    }

    private func makeLanguageRow() -> NSStackView {
        languagePopup.removeAllItems()
        for preference in FlowSoundLanguagePreference.allCases {
            languagePopup.addItem(withTitle: preference.label)
            languagePopup.lastItem?.representedObject = preference.rawValue
        }
        setFixedWidth(220, for: languagePopup)
        return controlRow(FlowSoundStrings.text(.language), languagePopup)
    }

    private func makeMusicPlayerRow() -> NSStackView {
        musicPlayerPopup.removeAllItems()
        for player in ControlledMusicPlayer.allCases {
            let title = player.supportLevel == .official ? player.displayName : "\(player.displayName) - \(player.supportLevel.rawValue)"
            musicPlayerPopup.addItem(withTitle: title)
            musicPlayerPopup.lastItem?.representedObject = player.rawValue
        }
        setFixedWidth(220, for: musicPlayerPopup)
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
        setFixedWidth(220, for: monitoringModePopup)
        return controlRow(FlowSoundStrings.text(.audioMonitoring), monitoringModePopup)
    }

    private func makeLaunchSection() -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8

        let titleView = NSTextField(labelWithString: FlowSoundStrings.text(.launchAtLogin))
        titleView.font = .systemFont(ofSize: 13, weight: .semibold)
        section.addArrangedSubview(titleView)

        launchAtLoginCheckbox.target = self
        loginItemStatusLabel.textColor = .secondaryLabelColor
        loginItemStatusLabel.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        section.addArrangedSubview(launchAtLoginCheckbox)
        section.addArrangedSubview(loginItemStatusLabel)
        return section
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

    private func makeRecentSourcesHeader() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let refreshButton = NSButton(title: FlowSoundStrings.text(.refresh), target: self, action: #selector(refreshRecentAudioSources))
        row.addArrangedSubview(refreshButton)
        return row
    }

    private func makeRecentSourcesList() -> NSScrollView {
        recentSourcesStack.orientation = .vertical
        recentSourcesStack.alignment = .leading
        recentSourcesStack.spacing = 8
        recentSourcesStack.translatesAutoresizingMaskIntoConstraints = true
        recentSourcesStack.autoresizingMask = [.width]
        recentSourcesStack.frame = NSRect(x: 10, y: 10, width: Layout.contentWidth - 20, height: 230)

        recentSourcesDocumentView.subviews.forEach { $0.removeFromSuperview() }
        recentSourcesDocumentView.frame = NSRect(x: 0, y: 0, width: Layout.contentWidth, height: 250)
        recentSourcesDocumentView.addSubview(recentSourcesStack)

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = recentSourcesDocumentView
        scrollView.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 250).isActive = true

        return scrollView
    }

    private func makeDiagnosticsRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.menuShowDiagnostics), target: self, action: #selector(showDiagnostics)))
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.menuCopyDiagnostics), target: self, action: #selector(copyDiagnosticsPath)))
        return row
    }

    private func makeAdapterProfileActionsRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.importAdapterProfile), target: self, action: #selector(importAdapterProfile)))
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.exportBundledAdapterProfile), target: self, action: #selector(exportNeteaseAdapterProfile)))
        return row
    }

    private func makeAccessibilitySettingsRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.openAccessibilitySettings), target: self, action: #selector(openAccessibilitySettings)))
        return row
    }

    private func makeAdapterProfilesList() -> NSStackView {
        adapterProfilesStack.orientation = .vertical
        adapterProfilesStack.alignment = .leading
        adapterProfilesStack.spacing = 6
        refreshAdapterProfiles()
        return adapterProfilesStack
    }

    private func makeButtonRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.resetDefaults), target: self, action: #selector(resetDefaults)))
        row.addArrangedSubview(NSButton(title: FlowSoundStrings.text(.openLoginItems), target: self, action: #selector(openLoginItems)))
        let saveButton = NSButton(title: FlowSoundStrings.text(.save), target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
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
        labelView.widthAnchor.constraint(equalToConstant: Layout.labelWidth).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(control)
        return row
    }

    private func formRow(_ label: String, _ field: NSTextField, _ help: String) -> NSStackView {
        let row = controlRow(label, field)
        field.alignment = .right
        field.placeholderString = "0.0"
        field.toolTip = help
        setFixedWidth(Layout.fieldWidth, for: field)

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
        selectLanguagePreference(settings.languagePreference)
        selectMusicPlayer(settings.controlledMusicPlayer)
        selectMonitoringMode(settings.monitoringMode)
        activeThresholdField.stringValue = Self.format(settings.activeThreshold)
        activeDurationField.stringValue = Self.format(settings.activeDuration)
        quietDurationField.stringValue = Self.format(settings.quietDuration)
        fadeOutDurationField.stringValue = Self.format(settings.fadeOutDuration)
        fadeInDurationField.stringValue = Self.format(settings.fadeInDuration)
        watchedBundleIdentifiersTextView.string = settings.watchedBundleIdentifiers.joined(separator: "\n")
        excludedBundleIdentifiersTextView.string = settings.excludedBundleIdentifiers.joined(separator: "\n")
        let launchAtLoginState = LoginItemController.isEnabledOrPendingApproval
        loadedLaunchAtLoginState = launchAtLoginState
        launchAtLoginCheckbox.state = launchAtLoginState ? .on : .off
        loginItemStatusLabel.stringValue = LoginItemController.statusText
        updateBundleIdentifierEditorAvailability()
    }

    @objc private func save() {
        var settings = settingsStore.settings
        let oldLanguagePreference = settings.languagePreference
        settings.languagePreference = selectedLanguagePreference()
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
        settingsStore.settings = settings
        updateLaunchAtLogin()

        if oldLanguagePreference != settings.languagePreference {
            rebuildWindow()
        } else {
            populateFields()
            refreshRecentAudioSources()
            refreshAdapterProfiles()
        }
    }

    @objc private func resetDefaults() {
        settingsStore.reset()
        rebuildWindow()
    }

    private func rebuildWindow() {
        let oldWindow = window
        window = nil
        oldWindow?.contentView = nil
        oldWindow?.close()
        resetReusableViewsForNewWindow()
        show()
    }

    private func resetReusableViewsForNewWindow() {
        contentHeightConstraint?.isActive = false
        contentHeightConstraint = nil
        tabContentViews.removeAll()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        contentContainer.removeFromSuperview()
        tabControl.removeFromSuperview()
        launchAtLoginCheckbox.title = FlowSoundStrings.text(.launchAtLogin)
        recentSourcesDocumentView.subviews.forEach { $0.removeFromSuperview() }
    }

    private func setFixedWidth(_ width: CGFloat, for view: NSView) {
        let identifier = ObjectIdentifier(view)
        guard !fixedWidthViews.contains(identifier) else {
            return
        }
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        fixedWidthViews.insert(identifier)
    }

    private func selectLanguagePreference(_ preference: FlowSoundLanguagePreference) {
        let index = FlowSoundLanguagePreference.allCases.firstIndex(of: preference) ?? 0
        languagePopup.selectItem(at: index)
    }

    private func selectedLanguagePreference() -> FlowSoundLanguagePreference {
        guard let rawValue = languagePopup.selectedItem?.representedObject as? String,
              let preference = FlowSoundLanguagePreference(rawValue: rawValue)
        else {
            return .system
        }
        return preference
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

    @objc private func refreshRecentAudioSources() {
        recentSourcesStack.arrangedSubviews.forEach { view in
            recentSourcesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let sources = RecentAudioSourceStore.shared.recentSources()
        guard !sources.isEmpty else {
            let empty = NSTextField(wrappingLabelWithString: FlowSoundStrings.text(.recentAudioSourcesEmpty))
            empty.textColor = .secondaryLabelColor
            empty.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 18).isActive = true
            recentSourcesStack.addArrangedSubview(empty)
            updateRecentSourcesDocumentHeight(rowCount: 1)
            return
        }

        for source in sources {
            recentSourcesStack.addArrangedSubview(makeRecentSourceRow(source))
        }
        updateRecentSourcesDocumentHeight(rowCount: sources.count)
    }

    private func refreshAdapterProfiles() {
        adapterProfilesStack.arrangedSubviews.forEach { view in
            adapterProfilesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for profile in MusicAdapterProfileStore.shared.profiles {
            let label = NSTextField(wrappingLabelWithString: "\(profile.displayName) - \(profile.supportLevel.rawValue) - \(profile.playbackStateCapability.rawValue) / \(profile.volumeControlCapability.rawValue)")
            label.textColor = profile.supportLevel == .official ? .labelColor : .secondaryLabelColor
            label.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
            adapterProfilesStack.addArrangedSubview(label)
        }
    }

    private func updateRecentSourcesDocumentHeight(rowCount: Int) {
        let height = max(CGFloat(rowCount) * 54 + 20, 250)
        recentSourcesDocumentView.setFrameSize(NSSize(width: Layout.contentWidth, height: height))
        recentSourcesStack.frame = NSRect(x: 10, y: 10, width: Layout.contentWidth - 20, height: height - 20)
    }

    private func makeRecentSourceRow(_ source: RecentAudioSource) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)

        let iconView = NSImageView()
        iconView.image = appIcon(for: source)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        let title = NSTextField(labelWithString: appName(for: source))
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: "\(source.bundleIdentifier)  pid=\(source.pid)")
        detail.textColor = .secondaryLabelColor
        detail.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detail.lineBreakMode = .byTruncatingMiddle
        detail.maximumNumberOfLines = 1
        textStack.widthAnchor.constraint(equalToConstant: 390).isActive = true
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(detail)

        let status = NSTextField(labelWithString: statusLabel(for: source.status))
        status.textColor = statusColor(for: source.status)
        status.alignment = .right
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.lineBreakMode = .byTruncatingTail
        status.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(status)
        row.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 28).isActive = true
        return row
    }

    private func appName(for source: RecentAudioSource) -> String {
        NSRunningApplication(processIdentifier: source.pid)?.localizedName ?? source.bundleIdentifier
    }

    private func appIcon(for source: RecentAudioSource) -> NSImage? {
        NSRunningApplication(processIdentifier: source.pid)?.icon
            ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
    }

    private func statusLabel(for status: RecentAudioSourceStatus) -> String {
        switch status {
        case .watched:
            FlowSoundStrings.text(.appStatusWatched)
        case .excluded:
            FlowSoundStrings.text(.appStatusExcluded)
        case .detected:
            FlowSoundStrings.text(.appStatusDetected)
        case .selectedMusicApp:
            FlowSoundStrings.text(.appStatusSelectedMusic)
        }
    }

    private func statusColor(for status: RecentAudioSourceStatus) -> NSColor {
        switch status {
        case .watched:
            .systemGreen
        case .excluded:
            .secondaryLabelColor
        case .detected:
            .systemBlue
        case .selectedMusicApp:
            .systemPurple
        }
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

    @objc private func showDiagnostics() {
        diagnosticsWindowController.show()
    }

    @objc private func importAdapterProfile() {
        do {
            let directory = try Self.adapterProfileExportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension.lowercased() == "json" }

            guard !urls.isEmpty else {
                NSWorkspace.shared.open(directory)
                showAlert(message: FlowSoundStrings.text(.importAdapterProfileEmpty(directory.path)))
                return
            }

            for url in urls {
                try MusicAdapterProfileStore.shared.importProfile(from: url)
            }
            refreshAdapterProfiles()
            showAlert(message: FlowSoundStrings.text(.importAdapterProfileCompleted(urls.count, directory.path)))
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    @objc private func exportNeteaseAdapterProfile() {
        guard let profile = MusicAdapterProfileStore.bundledProfiles.first(where: { $0.id == "community.netease-cloud-music.menu-tap" }) else {
            return
        }
        do {
            let directory = try Self.adapterProfileExportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("netease-cloud-music.flowsound-adapter.json")
            try MusicAdapterProfileStore.shared.exportProfile(profile, to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            showAlert(message: FlowSoundStrings.text(.exportAdapterProfileCompleted(url.path)))
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = FlowSoundStrings.text(.adapterProfiles)
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static func adapterProfileExportDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("FlowSound", isDirectory: true)
        .appendingPathComponent("AdapterProfiles", isDirectory: true)
    }

    @objc private func copyDiagnosticsPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(FlowSoundDiagnostics.logPath, forType: .string)
    }
}
