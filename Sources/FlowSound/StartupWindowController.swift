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
    private let monitorLabel = NSTextField(wrappingLabelWithString: "")
    private let automationLabel = NSTextField(wrappingLabelWithString: "")
    private let accessibilityLabel = NSTextField(wrappingLabelWithString: "")
    private let signalLabel = NSTextField(wrappingLabelWithString: "")
    private let restoreLabel = NSTextField(wrappingLabelWithString: "")
    private let loginLabel = NSTextField(wrappingLabelWithString: "")
    private var retryButton: NSButton?
    private var simulateButtons: [NSButton] = []
    private var advancedSection: NSStackView?
    private var document: NSView?
    private var content: NSStackView?

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

    private func buildWindow() {
        displayedLanguage = .current
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        let title = NSTextField(labelWithString: FlowSoundStrings.text(.diagnosticsTitle))
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        stack.addArrangedSubview(title)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        stack.addArrangedSubview(label("FlowSound \(version) · \(ProcessInfo.processInfo.operatingSystemVersionString)"))
        for view in [stateLabel, monitorLabel, automationLabel, accessibilityLabel, signalLabel, restoreLabel, loginLabel] {
            view.widthAnchor.constraint(equalToConstant: 620).isActive = true
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            stack.addArrangedSubview(view)
        }
        let mixHelp = label(FlowSoundStrings.text(.diagnosticMixHelp))
        mixHelp.textColor = .secondaryLabelColor
        stack.addArrangedSubview(mixHelp)
        let retry = button(.retryService, action: #selector(retry))
        retryButton = retry
        stack.addArrangedSubview(row([retry, button(.openAudioCaptureSettings, action: #selector(openAudioSettings)), button(.openAutomationSettings, action: #selector(openAutomationSettings))]))
        stack.addArrangedSubview(row([button(.openAccessibilitySettings, action: #selector(openAccessibilitySettings)), button(.openLoginItems, action: #selector(openLoginItems))]))
        let logPath = label(FlowSoundStrings.text(.startupDiagnostics(FlowSoundDiagnostics.logPath)))
        logPath.textColor = .secondaryLabelColor
        logPath.isSelectable = true
        stack.addArrangedSubview(logPath)
        stack.addArrangedSubview(button(.startupCopyLogPath, action: #selector(copyDiagnosticsPath)))
        let advancedToggle = NSButton(checkboxWithTitle: FlowSoundStrings.text(.advancedDiagnostics), target: self, action: #selector(toggleAdvanced(_:)))
        stack.addArrangedSubview(advancedToggle)
        let advanced = NSStackView()
        advanced.orientation = .vertical
        advanced.alignment = .leading
        advanced.spacing = 8
        advanced.addArrangedSubview(label(FlowSoundStrings.text(.simulationHelp)))
        simulateButtons = [button(.menuSimulateActive, action: #selector(simulateActive)), button(.menuSimulateQuiet, action: #selector(simulateQuiet))]
        advanced.addArrangedSubview(row(simulateButtons))
        advanced.isHidden = true
        advancedSection = advanced
        stack.addArrangedSubview(advanced)

        let document = DiagnosticsDocumentView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            stack.widthAnchor.constraint(equalToConstant: 620)
        ])
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = document
        self.document = document
        self.content = stack
        let diagnosticsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 660), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        diagnosticsWindow.minSize = NSSize(width: 680, height: 380)
        diagnosticsWindow.title = FlowSoundStrings.text(.diagnosticsTitle)
        diagnosticsWindow.contentView = scroll
        diagnosticsWindow.delegate = self
        diagnosticsWindow.isReleasedWhenClosed = false
        diagnosticsWindow.center()
        window = diagnosticsWindow
    }

    private func refresh() {
        let settings = settingsStore.settings
        stateLabel.stringValue = FlowSoundStrings.text(.status(service.state.label(playerName: settings.controlledMusicPlayer.displayName)))
        monitorLabel.stringValue = "\(FlowSoundStrings.text(.diagnosticMonitor)): \(monitorStatusText)"
        let automation: String
        if let error = service.lastControlError {
            automation = FlowSoundStrings.text(.diagnosticFailure(error))
        } else if let date = service.lastControlSucceededAt {
            automation = FlowSoundStrings.text(.automationSucceeded(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)))
        } else {
            automation = FlowSoundStrings.text(.notVerified)
        }
        automationLabel.stringValue = "\(FlowSoundStrings.text(.diagnosticAutomation)) (\(settings.controlledMusicPlayer.displayName)): \(automation)"
        automationLabel.textColor = service.lastControlError == nil ? .labelColor : .systemRed
        let accessibility: FlowSoundStrings.Key = settings.controlledMusicPlayer == .neteaseCloudMusic
            ? (AXIsProcessTrusted() ? .permissionAllowed : .permissionNotAllowed) : .permissionNotNeeded
        accessibilityLabel.stringValue = "\(FlowSoundStrings.text(.diagnosticAccessibility)): \(FlowSoundStrings.text(accessibility))"
        signalLabel.stringValue = "\(FlowSoundStrings.text(.diagnosticSignal)): \(FlowSoundStrings.text(service.lastActivity == .active ? .diagnosticSignalActive : .diagnosticSignalQuiet))"
        if let deadline = service.restoreDeadline {
            restoreLabel.stringValue = FlowSoundStrings.text(.restoreCountdown(max(0, Int(ceil(deadline.timeIntervalSinceNow)))))
        } else {
            restoreLabel.stringValue = FlowSoundStrings.text(.restoreNotScheduled)
        }
        loginLabel.stringValue = LoginItemController.statusText
        let running = service.monitorStatus == .running
        simulateButtons.forEach { $0.isEnabled = running }
        if case .error = service.state {
            retryButton?.isEnabled = true
        } else {
            retryButton?.isEnabled = false
        }
        resizeDocument()
    }

    private var monitorStatusText: String {
        switch service.monitorStatus {
        case .stopped: FlowSoundStrings.text(.monitorStopped)
        case .starting: FlowSoundStrings.text(.monitorStarting)
        case .running: FlowSoundStrings.text(.monitorRunning)
        case .recovering: FlowSoundStrings.text(.monitorRecovering)
        case .failed(let message): FlowSoundStrings.text(.diagnosticFailure(message))
        }
    }

    private func resizeDocument() {
        content?.layoutSubtreeIfNeeded()
        document?.setFrameSize(NSSize(width: 660, height: max(620, (content?.fittingSize.height ?? 0) + 40)))
    }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.widthAnchor.constraint(equalToConstant: 620).isActive = true
        return label
    }

    private func button(_ key: FlowSoundStrings.Key, action: Selector) -> NSButton {
        NSButton(title: FlowSoundStrings.text(key), target: self, action: action)
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.spacing = 10
        return row
    }

    @objc private func retry() { service.retry(); refresh() }
    @objc private func simulateActive() { activityMonitor.simulateActive(); refresh() }
    @objc private func simulateQuiet() { activityMonitor.simulateQuiet(); refresh() }
    @objc private func toggleAdvanced(_ sender: NSButton) { advancedSection?.isHidden = sender.state != .on; resizeDocument() }
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
