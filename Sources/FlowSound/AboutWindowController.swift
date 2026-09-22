import AppKit

@MainActor
final class AboutWindowController {
    private var window: NSWindow?
    private var displayedLanguage: FlowSoundLanguage?

    func show() {
        if displayedLanguage != FlowSoundLanguage.current {
            window?.close()
            window = nil
        }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        displayedLanguage = .current

        let content = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let image = loadAppIcon() ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        if let image {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 16
            imageView.layer?.cornerCurve = .continuous
            imageView.layer?.masksToBounds = true
            imageView.setAccessibilityElement(false)
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 72),
                imageView.heightAnchor.constraint(equalToConstant: 72)
            ])
            stack.addArrangedSubview(imageView)
            stack.setCustomSpacing(16, after: imageView)
        }

        let title = NSTextField(labelWithString: "FlowSound")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(title)

        let version = NSTextField(labelWithString: FlowSoundStrings.text(.version(Self.appVersion)))
        version.font = .systemFont(ofSize: 13)
        version.textColor = .secondaryLabelColor
        version.isSelectable = true
        stack.addArrangedSubview(version)
        stack.setCustomSpacing(16, after: version)

        let detail = NSTextField(wrappingLabelWithString: FlowSoundStrings.text(.aboutDetail))
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabelColor
        detail.alignment = .center
        detail.setContentCompressionResistancePriority(.required, for: .vertical)
        detail.widthAnchor.constraint(equalToConstant: 312).isActive = true
        stack.addArrangedSubview(detail)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
        ])

        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 268),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = FlowSoundStrings.text(.aboutTitle)
        aboutWindow.contentView = content
        aboutWindow.center()
        aboutWindow.isReleasedWhenClosed = false
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = aboutWindow
    }

    private func loadAppIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "FlowSound", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: NSImage.applicationIconName)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "Development"
    }
}
