import AppKit

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class RecentSourceActionButton: NSButton {
    var bundleIdentifier: String = ""
}

@MainActor
final class PreferencesWindowController: NSObject, NSToolbarDelegate, NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate {
    private enum Layout {
        static let width: CGFloat = 820
        static let defaultHeight: CGFloat = 450
        static let minimumHeight: CGFloat = 420
        static let contentWidth: CGFloat = 772
        static let fieldWidth: CGFloat = 66
        static let recentSourcesHeight: CGFloat = 186
    }

    private enum PreferencesTab: Int, CaseIterable {
        case general, monitoring, timing, tools

        var title: String {
            switch self {
            case .general: FlowSoundStrings.text(.generalTab)
            case .monitoring: localized("Applications", "应用规则")
            case .timing: localized("Sound", "声音调节")
            case .tools: FlowSoundStrings.text(.toolsTab)
            }
        }
        var symbol: String {
            switch self {
            case .general: "slider.horizontal.3"
            case .monitoring: "app.badge.checkmark"
            case .timing: "waveform"
            case .tools: "wrench.and.screwdriver"
            }
        }
        var contentHeight: CGFloat {
            switch self {
            case .general: 450
            case .monitoring: 650
            case .timing: 560
            case .tools: 610
            }
        }
        var identifier: NSToolbarItem.Identifier { .init("FlowSound.Settings.\(rawValue)") }
    }

    private typealias RecentSourceList = ApplicationRuleDraft.List

    private let settingsStore: FlowSoundSettingsStore
    private let diagnosticsWindowController: StartupWindowController
    private var experimentalSection: NSView?
    private var watchedRulesColumn: ApplicationRuleColumn?
    private var excludedRulesColumn: ApplicationRuleColumn?
    private let fixedExclusionsLabel = NSTextField(wrappingLabelWithString: "")
    private var timingSliders: [NSSlider] = []
    private var profileSection: NSView?
    private let footerStatus = NSTextField(labelWithString: "")
    private var advancedRulesSection: NSView?
    private var advancedRulesButton: NSButton?
    private var window: NSWindow?
    private var loadedLaunchAtLoginState: Bool?
    private var selectedTab: PreferencesTab = .general
    private var preferencesToolbar: NSToolbar?
    private let contentContainer = NSView()
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

    init(settingsStore: FlowSoundSettingsStore, service: FlowSoundService, activityMonitor: SimulatableAudioActivityMonitor) {
        self.settingsStore = settingsStore
        self.diagnosticsWindowController = StartupWindowController(service: service, activityMonitor: activityMonitor, settingsStore: settingsStore)
        super.init()
    }

    func show() {
        if let window {
            if !window.isVisible { populateFields() }
            refreshRecentAudioSources()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        resetReusableViewsForNewWindow()
        let root = NSView()
        let footer = makeButtonRow()
        let divider = separator()
        for view in [contentContainer, footer, divider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: root.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            contentContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: divider.topAnchor, constant: -12),
            divider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            footer.heightAnchor.constraint(equalToConstant: 28)
        ])
        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.defaultHeight),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        preferencesWindow.identifier = .init("FlowSound.Settings")
        preferencesWindow.title = selectedTab.title
        preferencesWindow.contentView = root
        preferencesWindow.contentMinSize = NSSize(width: Layout.width, height: Layout.minimumHeight)
        preferencesWindow.contentMaxSize = NSSize(width: Layout.width, height: 1200)
        preferencesWindow.delegate = self
        preferencesWindow.isReleasedWhenClosed = false
        let toolbar = NSToolbar(identifier: "FlowSound.Settings.Toolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = selectedTab.identifier
        preferencesToolbar = toolbar
        preferencesWindow.toolbar = toolbar
        preferencesWindow.toolbarStyle = .preference
        preferencesWindow.center()
        window = preferencesWindow
        PreferencesTab.allCases.forEach { _ = contentView(for: $0) }
        showSelectedTab(adjustWindow: false)
        populateFields()
        refreshRecentAudioSources()
        if let screen = preferencesWindow.screen ?? NSScreen.main {
            var frame = preferencesWindow.frame
            frame.size.height = min(frame.height, screen.visibleFrame.height - 40)
            frame.origin.y = min(frame.origin.y, screen.visibleFrame.maxY - frame.height)
            preferencesWindow.setFrame(frame, display: true)
        }
        preferencesWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshTabDocumentHeights()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        PreferencesTab.allCases.map(\.identifier)
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = PreferencesTab.allCases.first(where: { $0.identifier == identifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = tab.title
        item.paletteLabel = tab.title
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
        item.tag = tab.rawValue
        item.target = self
        item.action = #selector(tabChanged(_:))
        return item
    }
    @objc private func tabChanged(_ sender: NSToolbarItem) {
        guard let tab = PreferencesTab(rawValue: sender.tag) else { return }
        selectedTab = tab
        refreshApplicationRulesSummary()
        showSelectedTab(adjustWindow: true)
        refreshRecentAudioSources()
    }
    private func showSelectedTab(adjustWindow: Bool) {
        for (tab, view) in tabContentViews { view.isHidden = tab != selectedTab }
        window?.title = selectedTab.title
        preferencesToolbar?.selectedItemIdentifier = selectedTab.identifier
        if adjustWindow { resizeWindowForPane() }
        refreshTabDocumentHeights()
    }
    func windowDidResize(_ notification: Notification) { refreshTabDocumentHeights() }
    private func resizeWindowForPane() {
        guard let window else { return }
        let height = selectedTab.contentHeight + (selectedTab == .general && selectedMusicPlayer() == .neteaseCloudMusic ? 110 : 0)
        let size = NSSize(width: Layout.width, height: height)
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        let available = (window.screen ?? NSScreen.main)?.visibleFrame
        frame.size.height = min(frame.height, (available?.height ?? frame.height + 40) - 40)
        frame.origin.x = window.frame.origin.x
        frame.origin.y = window.frame.maxY - frame.height
        if let available { frame.origin.y = max(available.minY, frame.origin.y) }
        window.setFrame(frame, display: true)
    }

    private func contentView(for tab: PreferencesTab) -> NSView {
        if let view = tabContentViews[tab] { return view }
        let content: NSView
        switch tab {
        case .general: content = makeGeneralTab()
        case .monitoring: content = makeMonitoringTab()
        case .timing: content = makeTimingTab()
        case .tools: content = makeToolsTab()
        }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        let document = FlippedDocumentView()
        content.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: document.topAnchor, constant: 22),
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            content.widthAnchor.constraint(equalToConstant: Layout.contentWidth)
        ])
        scroll.documentView = document
        scroll.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        scroll.isHidden = tab != selectedTab
        tabContentViews[tab] = scroll
        return scroll
    }
    private func refreshTabDocumentHeights() {
        for view in tabContentViews.values {
            guard let scroll = view as? NSScrollView, let document = scroll.documentView,
                  let content = document.subviews.first else { continue }
            content.layoutSubtreeIfNeeded()
            document.setFrameSize(NSSize(width: Layout.contentWidth, height: max(scroll.contentSize.height, content.fittingSize.height + 44)))
        }
    }

    private func makeGeneralTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(pageHeading(localized("Music & system", "音乐与系统"),
            localized("FlowSound gently pauses your music when another app needs your attention.", "其他应用发声时，FlowSound 会轻柔地暂停音乐。")))
        content.addArrangedSubview(makeSection(title: localized("Music", "音乐"), help: "", rows: [makeMusicPlayerRow()]))
        let experimental = makeSection(title: localized("Experimental integration", "实验性支持"),
            help: localized("Netease needs Accessibility access. Volume restoration is approximate.", "网易云音乐需要辅助功能权限，恢复音量可能略有偏差。"),
            rows: [makeAccessibilitySettingsRow()])
        experimentalSection = experimental
        content.addArrangedSubview(experimental)
        content.addArrangedSubview(makeSection(title: localized("System", "系统"), help: "", rows: [makeLanguageRow(), makeLaunchSection()]))
        return content
    }

    private func makeMonitoringTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(pageHeading(localized("Application rules", "应用规则"),
            localized("Ignored apps never interrupt your music.", "被忽略的应用不会打断音乐。")))
        content.addArrangedSubview(makeSection(title: "", help: "", rows: [makeMonitoringModeRow()]))
        let watched = ApplicationRuleColumn(title: localized("Watched apps", "监听的应用"),
            emptyText: localized("Add the apps you want to listen for.", "添加需要监听的应用。"),
            accessibilityIdentifierPrefix: "watchedRules",
            onAdd: { [weak self] in self?.chooseWatchedApplications() },
            onRemove: { [weak self] in self?.removeApplicationFromDraft($0, from: .watched) })
        let excluded = ApplicationRuleColumn(title: localized("Ignored apps", "忽略的应用"),
            emptyText: localized("All other apps can interrupt your music.", "其他应用发声时均可打断音乐。"),
            accessibilityIdentifierPrefix: "excludedRules",
            onAdd: { [weak self] in self?.chooseExcludedApplications() },
            onRemove: { [weak self] in self?.removeApplicationFromDraft($0, from: .excluded) })
        watchedRulesColumn = watched
        excludedRulesColumn = excluded
        let columns = NSStackView(views: [watched, excluded])
        columns.spacing = 16
        columns.distribution = .fillEqually
        columns.alignment = .top
        columns.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        content.addArrangedSubview(columns)
        fixedExclusionsLabel.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        fixedExclusionsLabel.font = .systemFont(ofSize: 11)
        fixedExclusionsLabel.textColor = .secondaryLabelColor
        content.addArrangedSubview(fixedExclusionsLabel)
        let toggle = disclosure(localized("Advanced rules", "高级规则"), action: #selector(toggleAdvancedRules))
        advancedRulesButton = toggle
        content.addArrangedSubview(toggle)
        let advanced = makeSection(title: "", help: localized("One bundle identifier per line. Ignore rules take priority.", "每行一个 Bundle ID；忽略规则优先。"), rows: [
            makeBundleIdentifierEditor(title: localized("Watched apps", "监听的应用"), help: "", textView: watchedBundleIdentifiersTextView, height: 96),
            makeBundleIdentifierEditor(title: localized("Ignored apps", "忽略的应用"), help: "", textView: excludedBundleIdentifiersTextView, height: 96)
        ])
        advanced.isHidden = true
        advancedRulesSection = advanced
        content.addArrangedSubview(advanced)
        return content
    }

    private func makeTimingTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(pageHeading(localized("Sound & timing", "声音调节"),
            localized("Tune how quickly music makes way, and when it comes back.", "调整音乐淡出、等待和恢复的节奏。")))
        content.addArrangedSubview(makeSection(title: localized("Music transitions", "音乐过渡"), help: "", rows: [
            timingRow(localized("Fade out", "淡出时长"), detail: localized("Ease music down before pausing.", "暂停前，逐渐降低音量。"), field: fadeOutDurationField, range: 0.1...30),
            timingRow(localized("Resume after silence", "安静多久后恢复"), detail: localized("Wait for other apps to stay quiet.", "其他应用持续安静后再恢复。"), field: quietDurationField, range: 0.1...60),
            timingRow(localized("Fade in", "淡入时长"), detail: localized("Return to the previous volume smoothly.", "平滑恢复到原来的音量。"), field: fadeInDurationField, range: 0.1...30)
        ]))
        content.addArrangedSubview(makeSection(title: localized("Detection", "声音检测"), help: "", rows: [
            timingRow(localized("Minimum sound duration", "最短触发时长"), detail: localized("Skip sounds shorter than this.", "忽略短于此时长的声音。"), field: activeDurationField, range: 0.1...10),
            numericRow(localized("Activity threshold", "触发阈值"), field: activeThresholdField, detail: localized("Lower values respond to quieter audio. Default: 0.02.", "数值越低，越容易响应轻微声音。默认 0.02。"))
        ]))
        return content
    }

    private func makeToolsTab() -> NSStackView {
        let content = makeTabStack()
        content.addArrangedSubview(pageHeading(localized("Tools", "工具"),
            localized("Review recent audio sources or check how FlowSound is working.", "查看最近发声的应用，或检查 FlowSound 的运行状态。")))
        content.addArrangedSubview(makeSection(title: localized("Recent audio sources", "最近发声的应用"), help: "", rows: [makeRecentSourcesHeader(), makeRecentSourcesList()]))
        content.addArrangedSubview(makeSection(title: localized("Diagnostics", "诊断"), help: "", rows: [makeDiagnosticsRow()]))
        content.addArrangedSubview(disclosure(localized("Community adapters", "社区适配器"), action: #selector(toggleProfiles(_:))))
        let profiles = makeSection(title: "", help: FlowSoundStrings.text(.adapterProfilesHelp), rows: [makeAdapterProfileActionsRow(), makeAdapterProfilesList()])
        profiles.isHidden = true
        profileSection = profiles
        content.addArrangedSubview(profiles)
        return content
    }

    private func makeTabStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        return stack
    }
    private func pageHeading(_ title: String, _ detail: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: detail)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(subtitle)
        stack.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        return stack
    }
    private func makeLanguageRow() -> NSStackView {
        languagePopup.removeAllItems()
        for preference in FlowSoundLanguagePreference.allCases {
            languagePopup.addItem(withTitle: preference.label)
            languagePopup.lastItem?.representedObject = preference.rawValue
        }
        languagePopup.target = self
        languagePopup.action = #selector(settingsControlChanged)
        setFixedWidth(220, for: languagePopup)
        return controlRow(FlowSoundStrings.text(.language), languagePopup)
    }
    private func makeMusicPlayerRow() -> NSStackView {
        musicPlayerPopup.removeAllItems()
        for player in ControlledMusicPlayer.allCases {
            musicPlayerPopup.addItem(withTitle: player.supportLevel == .official ? player.displayName : "\(player.displayName) · \(localized("Experimental", "实验性"))")
            musicPlayerPopup.lastItem?.representedObject = player.rawValue
        }
        musicPlayerPopup.target = self
        musicPlayerPopup.action = #selector(musicPlayerChanged)
        setFixedWidth(270, for: musicPlayerPopup)
        return controlRow(FlowSoundStrings.text(.musicPlayer), musicPlayerPopup)
    }
    private func makeMonitoringModeRow() -> NSStackView {
        monitoringModePopup.removeAllItems()
        for mode in AudioMonitoringMode.allCases {
            monitoringModePopup.addItem(withTitle: mode == .allNonMusic ? localized("All apps, except ignored", "除忽略项外的所有应用") : localized("Only watched apps", "仅监听指定应用"))
            monitoringModePopup.lastItem?.representedObject = mode.rawValue
        }
        monitoringModePopup.target = self
        monitoringModePopup.action = #selector(monitoringModeChanged)
        setFixedWidth(260, for: monitoringModePopup)
        return controlRow(localized("Listen for", "监听范围"), monitoringModePopup)
    }
    private func makeLaunchSection() -> NSStackView {
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(settingsControlChanged)
        loginItemStatusLabel.font = .systemFont(ofSize: 11)
        loginItemStatusLabel.textColor = .secondaryLabelColor
        let text = NSStackView(views: [launchAtLoginCheckbox, loginItemStatusLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 5
        let open = NSButton(title: localized("Login Items…", "登录项设置…"), target: self, action: #selector(openLoginItems))
        open.controlSize = .small
        return flexibleRow(text, open)
    }
    private func makeSection(title: String, help: String, rows: [NSView]) -> NSStackView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        section.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        if !title.isEmpty {
            let heading = NSTextField(labelWithString: title)
            heading.font = .systemFont(ofSize: 13, weight: .semibold)
            section.addArrangedSubview(heading)
        }
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 12
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let line = separator()
                inner.addArrangedSubview(line)
                line.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
            }
            inner.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }
        if !help.isEmpty {
            let note = NSTextField(wrappingLabelWithString: help)
            note.textColor = .secondaryLabelColor
            note.font = .systemFont(ofSize: 11)
            inner.addArrangedSubview(note)
            note.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0.5
        box.borderColor = .separatorColor
        box.fillColor = .controlBackgroundColor
        box.cornerRadius = 10
        box.titlePosition = .noTitle
        box.contentViewMargins = NSSize(width: 16, height: 14)
        inner.translatesAutoresizingMaskIntoConstraints = false
        box.contentView = inner
        section.addArrangedSubview(box)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalTo: section.widthAnchor),
            box.heightAnchor.constraint(equalTo: inner.heightAnchor, constant: 28),
            inner.widthAnchor.constraint(equalTo: box.widthAnchor, constant: -32)
        ])
        return section
    }
    private func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
    private func disclosure(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.setButtonType(.pushOnPushOff)
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = .systemFont(ofSize: 12)
        button.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        button.alternateImage = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        button.alternateTitle = title
        button.symbolConfiguration = .init(pointSize: 9, weight: .semibold)
        button.imagePosition = .imageLeading
        (button.cell as? NSButtonCell)?.showsStateBy = .contentsCellMask
        button.setAccessibilityLabel(title)
        return button
    }
    private func makeBundleIdentifierEditor(title: String, help: String, textView: NSTextView, height: CGFloat) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        stack.addArrangedSubview(label)
        configureBundleIdentifierTextView(textView)
        textView.delegate = self
        textView.setAccessibilityLabel(title)
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
    private func makeRecentSourcesHeader() -> NSStackView {
        let note = NSTextField(labelWithString: localized("Seen in the last 3 minutes", "最近 3 分钟内"))
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        let refresh = NSButton(title: FlowSoundStrings.text(.refresh), target: self, action: #selector(refreshRecentAudioSources))
        refresh.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        refresh.imagePosition = .imageLeading
        refresh.controlSize = .small
        return flexibleRow(note, refresh)
    }
    private func makeRecentSourcesList() -> NSScrollView {
        recentSourcesStack.orientation = .vertical
        recentSourcesStack.alignment = .leading
        recentSourcesStack.spacing = 0
        recentSourcesStack.translatesAutoresizingMaskIntoConstraints = true
        recentSourcesStack.autoresizingMask = [.width]
        recentSourcesDocumentView.subviews.forEach { $0.removeFromSuperview() }
        recentSourcesDocumentView.addSubview(recentSourcesStack)
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = recentSourcesDocumentView
        scroll.heightAnchor.constraint(equalToConstant: Layout.recentSourcesHeight).isActive = true
        return scroll
    }
    private func makeDiagnosticsRow() -> NSStackView {
        let note = NSTextField(wrappingLabelWithString: localized("Monitoring, permissions and playback status.", "监听、权限和播放状态。"))
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor
        return flexibleRow(note, NSButton(title: localized("Open Diagnostics…", "打开诊断…"), target: self, action: #selector(showDiagnostics)))
    }
    private func makeAdapterProfileActionsRow() -> NSStackView {
        let row = NSStackView(views: [NSButton(title: FlowSoundStrings.text(.importAdapterProfile), target: self, action: #selector(importAdapterProfile)), NSButton(title: FlowSoundStrings.text(.exportBundledAdapterProfile), target: self, action: #selector(exportNeteaseAdapterProfile))])
        row.spacing = 8
        return row
    }
    private func makeAccessibilitySettingsRow() -> NSStackView {
        NSStackView(views: [NSButton(title: FlowSoundStrings.text(.openAccessibilitySettings), target: self, action: #selector(openAccessibilitySettings))])
    }
    private func makeAdapterProfilesList() -> NSStackView {
        adapterProfilesStack.orientation = .vertical
        adapterProfilesStack.alignment = .leading
        adapterProfilesStack.spacing = 8
        refreshAdapterProfiles()
        return adapterProfilesStack
    }
    private func makeButtonRow() -> NSStackView {
        let reset = NSButton(title: localized("Restore Defaults", "恢复默认"), target: self, action: #selector(resetDefaults))
        reset.controlSize = .small
        reset.identifier = .init("settings.reset")
        footerStatus.font = .systemFont(ofSize: 11)
        footerStatus.textColor = .secondaryLabelColor
        footerStatus.stringValue = localized("Changes apply when you save.", "修改将在保存后生效。")
        let cancel = NSButton(title: FlowSoundStrings.text(.cancel), target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        cancel.identifier = .init("settings.cancel")
        let save = NSButton(title: FlowSoundStrings.text(.save), target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        save.identifier = .init("settings.save")
        let space = NSView()
        space.setContentHuggingPriority(.init(1), for: .horizontal)
        let row = NSStackView(views: [reset, footerStatus, space, cancel, save])
        row.alignment = .centerY
        row.spacing = 12
        return row
    }
    private func flexibleRow(_ leading: NSView, _ trailing: NSView) -> NSStackView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        leading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        let row = NSStackView(views: [leading, spacer, trailing])
        row.spacing = 14
        row.alignment = .centerY
        return row
    }
    private func controlRow(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        control.setAccessibilityLabel(title)
        return flexibleRow(label, control)
    }
    private func timingRow(_ title: String, detail: String, field: NSTextField, range: ClosedRange<Double>) -> NSStackView {
        let text = NSStackView()
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 4
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 13)
        let subtitle = NSTextField(labelWithString: detail)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        text.addArrangedSubview(heading)
        text.addArrangedSubview(subtitle)
        let slider = SettingsTimingSlider(value: range.lowerBound, minValue: range.lowerBound, maxValue: range.upperBound, target: self, action: #selector(timingChanged(_:)))
        slider.numberField = field
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        slider.setAccessibilityLabel(title)
        timingSliders.append(slider)
        field.alignment = .right
        field.delegate = self
        field.setAccessibilityLabel(title)
        setFixedWidth(Layout.fieldWidth, for: field)
        let unit = NSTextField(labelWithString: localized("sec", "秒"))
        unit.font = .systemFont(ofSize: 11)
        unit.textColor = .secondaryLabelColor
        let controls = NSStackView(views: [slider, field, unit])
        controls.spacing = 8
        return flexibleRow(text, controls)
    }
    private func numericRow(_ title: String, field: NSTextField, detail: String) -> NSStackView {
        field.delegate = self
        field.alignment = .right
        field.toolTip = detail
        field.setAccessibilityLabel(title)
        setFixedWidth(Layout.fieldWidth, for: field)
        let text = NSStackView(views: [NSTextField(labelWithString: title), NSTextField(wrappingLabelWithString: detail)])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 4
        (text.arrangedSubviews.last as? NSTextField)?.font = .systemFont(ofSize: 11)
        (text.arrangedSubviews.last as? NSTextField)?.textColor = .secondaryLabelColor
        return flexibleRow(text, field)
    }
    @objc private func timingChanged(_ sender: SettingsTimingSlider) {
        sender.numberField?.stringValue = String(format: "%.1f", sender.doubleValue)
        markDraftChanged()
    }
    func controlTextDidChange(_ notification: Notification) {
        synchronizeTimingSliders()
        markDraftChanged()
    }
    func textDidChange(_ notification: Notification) {
        refreshApplicationRulesSummary()
        markDraftChanged()
    }
    private func synchronizeTimingSliders() {
        for case let slider as SettingsTimingSlider in timingSliders {
            if let field = slider.numberField, let value = Double(field.stringValue) { slider.doubleValue = value }
        }
    }
    @objc private func settingsControlChanged() { markDraftChanged() }
    private func markDraftChanged() { footerStatus.stringValue = localized("Changes apply when you save.", "修改将在保存后生效。") }
    @objc private func toggleProfiles(_ sender: NSButton) { profileSection?.isHidden = sender.state != .on; refreshTabDocumentHeights() }

    private func populateFields(settings draft: FlowSoundSettings? = nil) {
        let settings = draft ?? settingsStore.settings
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
        loginItemStatusLabel.textColor = .secondaryLabelColor
        synchronizeTimingSliders()
        markDraftChanged()
        updateBundleIdentifierEditorAvailability()
        musicPlayerChanged()
        refreshApplicationRulesSummary()
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
        let loginItemError = updateLaunchAtLogin()

        if oldLanguagePreference != settings.languagePreference {
            rebuildWindow()
        } else {
            populateFields()
            refreshRecentAudioSources()
            refreshAdapterProfiles()
        }
        footerStatus.stringValue = localized("Saved", "已保存")
        if let loginItemError {
            loginItemStatusLabel.textColor = .systemRed
            loginItemStatusLabel.stringValue = loginItemError
        }
    }

    @objc private func resetDefaults() {
        populateFields(settings: .defaults)
        refreshRecentAudioSources()
    }

    @objc private func cancel() {
        populateFields()
        window?.close()
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
        tabContentViews.removeAll()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        contentContainer.removeFromSuperview()
        preferencesToolbar = nil
        timingSliders.removeAll()
        watchedRulesColumn = nil
        excludedRulesColumn = nil
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
        watchedBundleIdentifiersTextView.isEditable = true
        watchedBundleIdentifiersTextView.isSelectable = true
        watchedBundleIdentifiersTextView.textColor = .labelColor

        excludedBundleIdentifiersTextView.isEditable = true
        excludedBundleIdentifiersTextView.isSelectable = true
        excludedBundleIdentifiersTextView.textColor = .labelColor
    }

    @objc private func monitoringModeChanged() {
        updateBundleIdentifierEditorAvailability()
        refreshApplicationRulesSummary()
        markDraftChanged()
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
            empty.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 56).isActive = true
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
            label.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 32).isActive = true
            adapterProfilesStack.addArrangedSubview(label)
        }
    }

    private func updateRecentSourcesDocumentHeight(rowCount: Int) {
        let height = max(CGFloat(rowCount) * 62, Layout.recentSourcesHeight)
        recentSourcesDocumentView.setFrameSize(NSSize(width: Layout.contentWidth - 32, height: height))
        recentSourcesStack.frame = NSRect(x: 0, y: 0, width: Layout.contentWidth - 48, height: height)
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
        let detail = NSTextField(labelWithString: source.bundleIdentifier)
        detail.textColor = .secondaryLabelColor
        detail.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detail.lineBreakMode = .byTruncatingMiddle
        detail.maximumNumberOfLines = 1
        textStack.widthAnchor.constraint(equalToConstant: 350).isActive = true
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(detail)

        let currentStatus = currentStatus(for: source)
        let status = NSTextField(labelWithString: statusLabel(for: currentStatus))
        status.textColor = statusColor(for: currentStatus)
        status.alignment = .right
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.lineBreakMode = .byTruncatingTail
        status.widthAnchor.constraint(equalToConstant: 100).isActive = true

        let watchButton = recentSourceActionButton(
            title: FlowSoundStrings.text(.addToWatchedApps),
            bundleIdentifier: source.bundleIdentifier,
            action: #selector(addRecentSourceToWatched(_:))
        )
        watchButton.isEnabled = currentStatus != .watched && currentStatus != .selectedMusicApp

        let excludeButton = recentSourceActionButton(
            title: FlowSoundStrings.text(.addToExcludedApps),
            bundleIdentifier: source.bundleIdentifier,
            action: #selector(addRecentSourceToExcluded(_:))
        )
        excludeButton.isEnabled = currentStatus != .excluded && currentStatus != .selectedMusicApp

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 6
        actionRow.addArrangedSubview(watchButton)
        actionRow.addArrangedSubview(excludeButton)

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(status)
        row.addArrangedSubview(actionRow)
        row.heightAnchor.constraint(equalToConstant: 62).isActive = true
        row.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 48).isActive = true
        return row
    }

    private func recentSourceActionButton(title: String, bundleIdentifier: String, action: Selector) -> RecentSourceActionButton {
        let button = RecentSourceActionButton(title: title, target: self, action: action)
        button.bundleIdentifier = bundleIdentifier
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        button.toolTip = bundleIdentifier
        button.widthAnchor.constraint(equalToConstant: 58).isActive = true
        return button
    }

    @objc private func addRecentSourceToWatched(_ sender: RecentSourceActionButton) {
        addRecentSource(sender.bundleIdentifier, to: .watched)
    }

    @objc private func addRecentSourceToExcluded(_ sender: RecentSourceActionButton) {
        addRecentSource(sender.bundleIdentifier, to: .excluded)
    }

    private func addRecentSource(_ bundleIdentifier: String, to list: RecentSourceList) {
        addApplicationsToDraft([bundleIdentifier], to: list)
    }

    private func addApplicationsToDraft(_ identifiers: [String], to list: RecentSourceList) {
        var draft = ApplicationRuleDraft(watchedText: watchedBundleIdentifiersTextView.string, excludedText: excludedBundleIdentifiersTextView.string)
        draft.add(identifiers, to: list)
        watchedBundleIdentifiersTextView.string = draft.watched.joined(separator: "\n")
        excludedBundleIdentifiersTextView.string = draft.excluded.joined(separator: "\n")
        refreshApplicationRulesSummary()
        refreshRecentAudioSources()
        markDraftChanged()
    }

    @objc private func chooseWatchedApplications() { chooseApplications(to: .watched) }
    @objc private func chooseExcludedApplications() { chooseApplications(to: .excluded) }

    private func chooseApplications(to list: RecentSourceList) {
        guard let window else { return }
        ApplicationRulePicker.chooseApplications(for: window) { [weak self] identifiers in
            self?.addApplicationsToDraft(identifiers, to: list)
        }
    }

    private func removeApplicationFromDraft(_ identifier: String, from list: RecentSourceList) {
        var draft = ApplicationRuleDraft(watchedText: watchedBundleIdentifiersTextView.string, excludedText: excludedBundleIdentifiersTextView.string)
        draft.remove(identifier, from: list)
        watchedBundleIdentifiersTextView.string = draft.watched.joined(separator: "\n")
        excludedBundleIdentifiersTextView.string = draft.excluded.joined(separator: "\n")
        refreshApplicationRulesSummary()
        refreshRecentAudioSources()
        markDraftChanged()
    }

    private func refreshApplicationRulesSummary() {
        let automatic = Set(selectedMusicPlayer().bundleIdentifiers + [Bundle.main.bundleIdentifier ?? "com.flowsound.FlowSound", "com.flowsound.FlowSound"])
        watchedRulesColumn?.update(identifiers: FlowSoundSettings.bundleIdentifiers(fromText: watchedBundleIdentifiersTextView.string).filter { !automatic.contains($0) }, inactive: selectedMonitoringMode() == .allNonMusic)
        excludedRulesColumn?.update(identifiers: FlowSoundSettings.bundleIdentifiers(fromText: excludedBundleIdentifiersTextView.string).filter { !automatic.contains($0) })
        fixedExclusionsLabel.stringValue = localized("Always ignored: \(selectedMusicPlayer().displayName) and FlowSound.", "始终忽略：\(selectedMusicPlayer().displayName) 和 FlowSound。")
    }

    @objc private func toggleAdvancedRules() {
        guard let advancedRulesSection else { return }
        advancedRulesSection.isHidden.toggle()
        advancedRulesButton?.state = advancedRulesSection.isHidden ? .off : .on
        refreshApplicationRulesSummary()
        refreshTabDocumentHeights()
    }

    @objc private func musicPlayerChanged() {
        markDraftChanged()
        experimentalSection?.isHidden = selectedMusicPlayer() != .neteaseCloudMusic
        if selectedTab == .general { resizeWindowForPane() }
        refreshApplicationRulesSummary()
        refreshRecentAudioSources()
        refreshTabDocumentHeights()
    }

    private func currentStatus(for source: RecentAudioSource) -> RecentAudioSourceStatus {
        let bundleIdentifier = source.bundleIdentifier
        let watched = Set(FlowSoundSettings.expandedWatchedBundleIdentifiers(
            FlowSoundSettings.bundleIdentifiers(fromText: watchedBundleIdentifiersTextView.string)
        ))
        let excluded = Set(FlowSoundSettings.validExcludedBundleIdentifiers(
            FlowSoundSettings.bundleIdentifiers(fromText: excludedBundleIdentifiersTextView.string)
        ))
        let selectedMusic = Set(selectedMusicPlayer().bundleIdentifiers)

        if selectedMusic.contains(bundleIdentifier) {
            return .selectedMusicApp
        }
        if excluded.contains(bundleIdentifier) {
            return .excluded
        }
        if watched.contains(bundleIdentifier) {
            return .watched
        }
        return .detected
    }

    private func appName(for source: RecentAudioSource) -> String {
        NSRunningApplication(processIdentifier: source.pid)?.localizedName ?? ApplicationRulePresentation.resolve(identifier: source.bundleIdentifier).name
    }

    private func appIcon(for source: RecentAudioSource) -> NSImage? {
        NSRunningApplication(processIdentifier: source.pid)?.icon
            ?? ApplicationRulePresentation.resolve(identifier: source.bundleIdentifier).image
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
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
    }

    private func updateLaunchAtLogin() -> String? {
        let requestedState = launchAtLoginCheckbox.state == .on
        guard requestedState != loadedLaunchAtLoginState else {
            loginItemStatusLabel.textColor = .secondaryLabelColor
            loginItemStatusLabel.stringValue = LoginItemController.statusText
            return nil
        }

        do {
            try LoginItemController.setEnabled(requestedState)
            loadedLaunchAtLoginState = LoginItemController.isEnabledOrPendingApproval
            loginItemStatusLabel.textColor = .secondaryLabelColor
            loginItemStatusLabel.stringValue = LoginItemController.statusText
            return nil
        } catch {
            return FlowSoundStrings.text(.automationUnavailable(error.localizedDescription))
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


@MainActor
private final class SettingsTimingSlider: NSSlider {
    weak var numberField: NSTextField?
}

private func localized(_ english: String, _ chinese: String) -> String {
    FlowSoundLanguage.current == .simplifiedChinese ? chinese : english
}
