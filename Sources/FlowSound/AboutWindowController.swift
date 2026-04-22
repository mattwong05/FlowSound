import AppKit

@MainActor
final class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = NSStackView()
        contentView.orientation = .vertical
        contentView.alignment = .centerX
        contentView.spacing = 14
        contentView.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        if let image = loadLogoForCurrentAppearance() {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 320),
                imageView.heightAnchor.constraint(equalToConstant: 220)
            ])
            contentView.addArrangedSubview(imageView)
        }

        let title = NSTextField(labelWithString: "FlowSound")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        contentView.addArrangedSubview(title)

        let version = NSTextField(labelWithString: FlowSoundStrings.text(.version(Self.appVersion)))
        version.textColor = .secondaryLabelColor
        contentView.addArrangedSubview(version)

        let detail = NSTextField(wrappingLabelWithString: FlowSoundStrings.text(.aboutDetail))
        detail.alignment = .center
        detail.maximumNumberOfLines = 2
        contentView.addArrangedSubview(detail)

        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = FlowSoundStrings.text(.aboutTitle)
        aboutWindow.contentView = contentView
        aboutWindow.center()
        aboutWindow.isReleasedWhenClosed = false
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = aboutWindow
    }

    private func loadBundledImage(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private func loadLogoForCurrentAppearance() -> NSImage? {
        let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        let preferredName = bestMatch == .darkAqua ? "FlowSoundLogoDarkBackground" : "FlowSoundLogoLightBackground"
        let fallbackName = bestMatch == .darkAqua ? "FlowSoundLogoLightBackground" : "FlowSoundLogoDarkBackground"
        return NSImage(named: preferredName)
            ?? loadBundledImage(named: preferredName)
            ?? loadBundledImage(named: fallbackName)
            ?? loadBundledImage(named: "FlowSound-iCon")
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.14.3"
    }
}
