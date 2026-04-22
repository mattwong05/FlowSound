import AppKit

@MainActor
final class StartupWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = NSStackView()
        contentView.orientation = .vertical
        contentView.alignment = .leading
        contentView.spacing = 12
        contentView.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)

        let title = NSTextField(labelWithString: FlowSoundStrings.text(.startupTitle))
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        contentView.addArrangedSubview(title)

        let message = NSTextField(wrappingLabelWithString: FlowSoundStrings.text(.startupMessage))
        message.maximumNumberOfLines = 3
        contentView.addArrangedSubview(message)

        let diagnostics = NSTextField(wrappingLabelWithString: FlowSoundStrings.text(.startupDiagnostics(FlowSoundDiagnostics.logPath)))
        diagnostics.textColor = .secondaryLabelColor
        diagnostics.maximumNumberOfLines = 3
        contentView.addArrangedSubview(diagnostics)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10

        let copyButton = NSButton(title: FlowSoundStrings.text(.startupCopyLogPath), target: self, action: #selector(copyDiagnosticsPath))
        let closeButton = NSButton(title: FlowSoundStrings.text(.startupClose), target: self, action: #selector(close))
        buttonRow.addArrangedSubview(copyButton)
        buttonRow.addArrangedSubview(closeButton)
        contentView.addArrangedSubview(buttonRow)

        let startupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        startupWindow.title = "FlowSound"
        startupWindow.contentView = contentView
        startupWindow.center()
        startupWindow.isReleasedWhenClosed = false
        startupWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = startupWindow
        FlowSoundDiagnostics.log("startup window shown")
    }

    @objc private func copyDiagnosticsPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(FlowSoundDiagnostics.logPath, forType: .string)
    }

    @objc private func close() {
        window?.close()
    }
}
