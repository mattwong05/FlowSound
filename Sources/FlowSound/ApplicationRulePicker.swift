import AppKit
import UniformTypeIdentifiers

@MainActor
enum ApplicationRulePicker {
    static func chooseApplications(for window: NSWindow, completion: @escaping ([String]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = FlowSoundStrings.text(.chooseApplications)
        panel.prompt = FlowSoundStrings.text(.addApplications)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            let identifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            let valid = FlowSoundSettings.normalizedBundleIdentifiers(identifiers)
            guard identifiers.count == panel.urls.count,
                  identifiers.allSatisfy({ FlowSoundSettings.normalizedBundleIdentifiers([$0]).count == 1 }) else {
                let alert = NSAlert()
                alert.messageText = FlowSoundStrings.text(.chooseApplications)
                alert.informativeText = FlowSoundStrings.text(.applicationMissingIdentifier)
                alert.beginSheetModal(for: window)
                return
            }
            completion(valid)
        }
    }

    static func summaryView(identifiers: [String], width: CGFloat, onRemove: @escaping (String) -> Void) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        for identifier in identifiers {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
                ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            let image = NSImageView()
            image.image = icon
            image.imageScaling = .scaleProportionallyUpOrDown
            image.widthAnchor.constraint(equalToConstant: 18).isActive = true
            image.heightAnchor.constraint(equalToConstant: 18).isActive = true
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? identifier
            let label = NSTextField(labelWithString: name)
            label.lineBreakMode = .byTruncatingTail
            label.toolTip = identifier
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let remove = ApplicationRuleRemoveButton()
            remove.title = FlowSoundStrings.text(.removeApplicationRule)
            remove.bezelStyle = .rounded
            remove.controlSize = .small
            remove.toolTip = identifier
            remove.setAccessibilityLabel("\(remove.title) \(name)")
            remove.onRemove = { onRemove(identifier) }
            remove.target = remove
            remove.action = #selector(ApplicationRuleRemoveButton.removeRule)
            let row = NSStackView(views: [image, label, remove])
            row.spacing = 6
            row.widthAnchor.constraint(equalToConstant: width).isActive = true
            stack.addArrangedSubview(row)
        }
        return stack
    }
}

@MainActor
private final class ApplicationRuleRemoveButton: NSButton {
    var onRemove: (() -> Void)?
    @objc func removeRule() { onRemove?() }
}
