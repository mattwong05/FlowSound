import AppKit
import ApplicationServices

/// A live view of the service; opening it never requests permissions or controls a player.
@MainActor
final class StartupWindowController: NSObject, NSWindowDelegate {
    private let service: FlowSoundService
    private let activityMonitor: SimulatableAudioActivityMonitor
    private let settingsStore: FlowSoundSettingsStore
    private var window: NSWindow?
    private var refreshTask: Task<Void, Never>?
    private var displayedLanguage: FlowSoundLanguage?
    private let stateLabel = NSTextField(wrappingLabelWithString: "")
    private let stateImage = NSImageView()
    private let monitorLabel = NSTextField(wrappingLabelWithString: "")
    private let automationLabel = NSTextField(wrappingLabelWithString: "")
    private let accessibilityLabel = NSTextField(wrappingLabelWithString: "")
    private let signalLabel = NSTextField(wrappingLabelWithString: "")
    private let restoreLabel = NSTextField(wrappingLabelWithString: "")
    private let loginLabel = NSTextField(wrappingLabelWithString: "")
    private var retryButton: NSButton?
    private var accessibilityButton: NSButton?
    private var simulateButtons: [NSButton] = []
    private var advancedSection: NSStackView?
    private var advancedToggleButton: NSButton?
    private var document: NSView?
    private var scrollView: NSScrollView?
    private var content: NSStackView?
    private var contentWidth: NSLayoutConstraint?

    init(service: FlowSoundService, activityMonitor: SimulatableAudioActivityMonitor, settingsStore: FlowSoundSettingsStore) {
        self.service = service
        self.activityMonitor = activityMonitor
        self.settingsStore = settingsStore
    }

    func show() {
        if displayedLanguage != FlowSoundLanguage.current {
            window?.close()
            window = nil
        }
        if window == nil { buildWindow() }
        refresh()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard let self, self.window?.isVisible == true else { return }
                self.refresh()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func windowDidResize(_ notification: Notification) { resizeDocument() }

    private func buildWindow() {
        displayedLanguage = .current
        let stack = verticalStack(spacing: 24)
        let heading = verticalStack(spacing: 8)
        let title = label(text("Diagnostics", "诊断"))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        heading.addArrangedSubview(title)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        heading.addArrangedSubview(label("FlowSound \(version) · \(ProcessInfo.processInfo.operatingSystemVersionString)", secondary: true))
        stack.addArrangedSubview(heading)

        stateLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stateLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        stateImage.symbolConfiguration = .init(pointSize: 22, weight: .medium)
        stateImage.setAccessibilityElement(false)
        stateImage.widthAnchor.constraint(equalToConstant: 28).isActive = true
        stateImage.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let retry = button(FlowSoundStrings.text(.retryService), action: #selector(retry))
        retryButton = retry
        let summary = NSStackView(views: [stateImage, stateLabel, retry])
        summary.alignment = .centerY
        summary.distribution = .fill
        summary.spacing = 12
        stateLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(card(summary, inset: 16))

        let captureSettings = settingsButton(action: #selector(openAudioSettings), accessibility: FlowSoundStrings.text(.openAudioCaptureSettings))
        stack.addArrangedSubview(section(
            text("Monitoring", "监听状态"),
            rows: [
                detailRow(FlowSoundStrings.text(.diagnosticMonitor), value: monitorLabel, action: captureSettings),
                detailRow(FlowSoundStrings.text(.diagnosticSignal), value: signalLabel),
                detailRow(text("Music restore", "音乐恢复"), value: restoreLabel)
            ],
            footer: FlowSoundStrings.text(.diagnosticMixHelp)
        ))

        let automationSettings = settingsButton(action: #selector(openAutomationSettings), accessibility: FlowSoundStrings.text(.openAutomationSettings))
        let accessibilitySettings = settingsButton(action: #selector(openAccessibilitySettings), accessibility: FlowSoundStrings.text(.openAccessibilitySettings))
        accessibilityButton = accessibilitySettings
        let loginSettings = settingsButton(action: #selector(openLoginItems), accessibility: FlowSoundStrings.text(.openLoginItems))
        stack.addArrangedSubview(section(
            text("Permissions & system", "权限与系统"),
            rows: [
                detailRow(FlowSoundStrings.text(.diagnosticAutomation), value: automationLabel, action: automationSettings),
                detailRow(FlowSoundStrings.text(.diagnosticAccessibility), value: accessibilityLabel, action: accessibilitySettings),
                detailRow(text("Launch at login", "登录时启动"), value: loginLabel, action: loginSettings)
            ],
            footer: text("Audio capture permissions are not independently verified. Automation status reflects the latest command.", "音频采集权限未单独验证；自动化状态反映最近一次命令的结果。")
        ))

        let advancedGroup = verticalStack(spacing: 12)
        // AppKit's disclosure bezel draws only a triangle. Keep the title in a
        // separate borderless button so both the label and triangle can toggle it.
        let advancedToggle = NSButton(title: "", target: self, action: #selector(toggleAdvanced(_:)))
        advancedToggle.setButtonType(.onOff)
        advancedToggle.bezelStyle = .disclosure
        advancedToggle.setAccessibilityLabel(FlowSoundStrings.text(.advancedDiagnostics))
        advancedToggle.widthAnchor.constraint(equalToConstant: 16).isActive = true
        advancedToggle.heightAnchor.constraint(equalToConstant: 20).isActive = true
        advancedToggleButton = advancedToggle
        let advancedTitle = NSButton(title: FlowSoundStrings.text(.advancedDiagnostics), target: self, action: #selector(toggleAdvancedTitle))
        advancedTitle.isBordered = false
        advancedTitle.alignment = .left
        advancedTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        advancedTitle.refusesFirstResponder = true
        advancedTitle.setAccessibilityElement(false)
        let disclosure = NSStackView(views: [advancedToggle, advancedTitle])
        disclosure.alignment = .centerY
        disclosure.spacing = 4
        advancedGroup.addArrangedSubview(disclosure)
        let advanced = verticalStack(spacing: 16)
        let logGroup = verticalStack(spacing: 8)
        let logHeader = NSStackView(views: [label(text("Local diagnostic log", "本地诊断日志")), NSView(), button(text("Copy Path", "复制路径"), action: #selector(copyDiagnosticsPath))])
        logHeader.spacing = 12
        logHeader.distribution = .fill
        logGroup.addArrangedSubview(logHeader)
        let logPath = label(FlowSoundDiagnostics.logPath, secondary: true)
        logPath.isSelectable = true
        logPath.lineBreakMode = .byCharWrapping
        logGroup.addArrangedSubview(logPath)
        advanced.addArrangedSubview(logGroup)
        advanced.addArrangedSubview(separator())
        advanced.addArrangedSubview(label(FlowSoundStrings.text(.simulationHelp), secondary: true))
        simulateButtons = [button(FlowSoundStrings.text(.menuSimulateActive), action: #selector(simulateActive)), button(FlowSoundStrings.text(.menuSimulateQuiet), action: #selector(simulateQuiet))]
        let simulationActions = NSStackView(views: simulateButtons)
        simulationActions.spacing = 8
        advanced.addArrangedSubview(simulationActions)
        advanced.isHidden = true
        advancedSection = advanced
        advancedGroup.addArrangedSubview(advanced)
        stack.addArrangedSubview(advancedGroup)

        let document = DiagnosticsDocumentView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        let widthConstraint = stack.widthAnchor.constraint(equalToConstant: 612)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            widthConstraint
        ])
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = document
        self.document = document
        self.scrollView = scroll
        self.content = stack
        self.contentWidth = widthConstraint
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 800
        let diagnosticsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: min(690, availableHeight - 100)), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        diagnosticsWindow.minSize = NSSize(width: 620, height: 420)
        diagnosticsWindow.title = FlowSoundStrings.text(.diagnosticsTitle)
        diagnosticsWindow.contentView = scroll
        diagnosticsWindow.delegate = self
        diagnosticsWindow.isReleasedWhenClosed = false
        diagnosticsWindow.center()
        window = diagnosticsWindow
    }

    private func refresh() {
        let settings = settingsStore.settings
        stateLabel.stringValue = service.state.label(playerName: settings.controlledMusicPlayer.displayName)
        let symbol: String
        let statusColor: NSColor
        switch service.state {
        case .error:
            symbol = "exclamationmark.triangle"
            statusColor = .systemOrange
        case .disabled:
            symbol = "pause.circle"
            statusColor = .secondaryLabelColor
        case .starting:
            symbol = "waveform"
            statusColor = .secondaryLabelColor
        case .listening:
            symbol = "waveform"
            statusColor = .controlAccentColor
        case .ducking, .pausedByFlowSound, .restoring:
            symbol = "music.note"
            statusColor = .controlAccentColor
        }
        stateImage.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        stateImage.contentTintColor = statusColor
        monitorLabel.stringValue = monitorStatusText
        let automation: String
        if let error = service.lastControlError {
            automation = FlowSoundStrings.text(.diagnosticFailure(error))
        } else if let date = service.lastControlSucceededAt {
            automation = FlowSoundStrings.text(.automationSucceeded(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)))
        } else {
            automation = FlowSoundStrings.text(.notVerified)
        }
        automationLabel.stringValue = "\(settings.controlledMusicPlayer.displayName) · \(automation)"
        automationLabel.textColor = service.lastControlError == nil ? .labelColor : .systemRed
        let accessibility: FlowSoundStrings.Key = settings.controlledMusicPlayer == .neteaseCloudMusic
            ? (AXIsProcessTrusted() ? .permissionAllowed : .permissionNotAllowed) : .permissionNotNeeded
        accessibilityLabel.stringValue = FlowSoundStrings.text(accessibility)
        accessibilityButton?.isHidden = settings.controlledMusicPlayer != .neteaseCloudMusic
        signalLabel.stringValue = service.monitorStatus == .running
            ? FlowSoundStrings.text(service.lastActivity == .active ? .diagnosticSignalActive : .diagnosticSignalQuiet)
            : FlowSoundStrings.text(.notVerified)
        if let deadline = service.restoreDeadline {
            restoreLabel.stringValue = FlowSoundStrings.text(.restoreCountdown(max(0, Int(ceil(deadline.timeIntervalSinceNow)))))
        } else {
            restoreLabel.stringValue = FlowSoundStrings.text(.restoreNotScheduled)
        }
        loginLabel.stringValue = LoginItemController.statusText
        simulateButtons.forEach { $0.isEnabled = service.monitorStatus == .running }
        if case .error = service.state { retryButton?.isHidden = false } else { retryButton?.isHidden = true }
        resizeDocument()
    }

    private var monitorStatusText: String {
        switch service.monitorStatus {
        case .stopped: FlowSoundStrings.text(.monitorStopped)
        case .starting: FlowSoundStrings.text(.monitorStarting)
        case .running: text("Running", "运行中")
        case .recovering: FlowSoundStrings.text(.monitorRecovering)
        case .failed(let message): FlowSoundStrings.text(.diagnosticFailure(message))
        }
    }

    private func resizeDocument() {
        guard let scrollView, let content, let document else { return }
        let width = scrollView.contentSize.width
        contentWidth?.constant = max(500, width - 48)
        content.layoutSubtreeIfNeeded()
        document.setFrameSize(NSSize(width: width, height: max(scrollView.contentSize.height, content.fittingSize.height + 48)))
    }

    private func text(_ english: String, _ chinese: String) -> String {
        FlowSoundLanguage.current == .simplifiedChinese ? chinese : english
    }

    private func label(_ text: String, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = secondary ? .secondaryLabelColor : .labelColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private func verticalStack(spacing: CGFloat) -> NSStackView {
        let stack = DiagnosticsStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func settingsButton(action: Selector, accessibility: String) -> NSButton {
        let button = button(text("Settings…", "设置…"), action: action)
        button.setAccessibilityLabel(accessibility)
        button.toolTip = accessibility
        return button
    }

    private func detailRow(_ title: String, value: NSTextField, action: NSButton? = nil) -> NSView {
        let name = label(title, secondary: true)
        name.widthAnchor.constraint(equalToConstant: 132).isActive = true
        value.font = .systemFont(ofSize: 13)
        value.isSelectable = true
        value.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        value.setContentCompressionResistancePriority(.required, for: .vertical)
        value.setAccessibilityLabel(title)
        let row = NSStackView(views: [name, value] + (action.map { [$0] } ?? []))
        row.alignment = .firstBaseline
        row.distribution = .fill
        row.spacing = 12
        return row
    }

    private func section(_ title: String, rows: [NSView], footer: String) -> NSStackView {
        let group = verticalStack(spacing: 8)
        let heading = label(title)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        group.addArrangedSubview(heading)
        let list = verticalStack(spacing: 12)
        for (index, row) in rows.enumerated() {
            if index > 0 { list.addArrangedSubview(separator()) }
            list.addArrangedSubview(row)
        }
        group.addArrangedSubview(card(list, inset: 16))
        group.addArrangedSubview(label(footer, secondary: true))
        return group
    }

    private func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    private func card(_ view: NSView, inset: CGFloat) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.fillColor = .controlBackgroundColor
        box.cornerRadius = 10
        box.contentViewMargins = .zero
        let container = NSView()
        box.contentView = container
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset)
        ])
        return box
    }

    @objc private func retry() { service.retry(); refresh() }
    @objc private func simulateActive() { activityMonitor.simulateActive(); refresh() }
    @objc private func simulateQuiet() { activityMonitor.simulateQuiet(); refresh() }
    @objc private func toggleAdvanced(_ sender: NSButton) { advancedSection?.isHidden = sender.state != .on; resizeDocument() }
    @objc private func toggleAdvancedTitle() {
        guard let button = advancedToggleButton else { return }
        button.state = button.state == .on ? .off : .on
        toggleAdvanced(button)
    }
    @objc private func openLoginItems() { LoginItemController.openSystemSettings() }
    @objc private func openAudioSettings() { openPrivacySettings("Privacy_ScreenCapture") }
    @objc private func openAutomationSettings() { openPrivacySettings("Privacy_Automation") }
    @objc private func openAccessibilitySettings() { openPrivacySettings("Privacy_Accessibility") }

    private func openPrivacySettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func copyDiagnosticsPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(FlowSoundDiagnostics.logPath, forType: .string)
    }
}

private final class DiagnosticsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

/// Keep native group backgrounds and row trailing actions on one common edge.
private final class DiagnosticsStackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        if !(view is NSButton) {
            view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        }
    }
}
