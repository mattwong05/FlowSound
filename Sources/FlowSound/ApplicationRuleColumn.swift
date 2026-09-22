import AppKit

/// One editable application-rule collection. Headers stay in place while only the rows scroll.
@MainActor
final class ApplicationRuleColumn: NSView {
    private let titleLabel: NSTextField
    private let countLabel = NSTextField(labelWithString: "")
    private let addButton = ApplicationRuleActionButton()
    private let scrollView = NSScrollView()
    private let rows = ApplicationRuleListView()
    private let emptyState = NSStackView()
    private let onRemove: (String) -> Void
    private let accessibilityIdentifierPrefix: String

    init(
        title: String,
        emptyText: String,
        accessibilityIdentifierPrefix: String = "applicationRules",
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) {
        titleLabel = NSTextField(labelWithString: title)
        self.onRemove = onRemove
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityIdentifier(accessibilityIdentifierPrefix)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.lineBreakMode = .byTruncatingTail
        countLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addButton.title = localized("Add", "添加")
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        addButton.imagePosition = .imageLeading
        addButton.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small
        addButton.font = .systemFont(ofSize: 12)
        addButton.onAction = onAdd
        addButton.setAccessibilityLabel("\(localized("Add application to", "添加应用至")) \(title)")
        addButton.setAccessibilityIdentifier("\(accessibilityIdentifierPrefix).add")
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let header = NSView()
        [titleLabel, countLabel, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }

        let group = ApplicationRuleGroupView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .automatic
        scrollView.setAccessibilityLabel(title)
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = rows

        let emptyImage = NSImageView()
        emptyImage.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
        emptyImage.contentTintColor = .tertiaryLabelColor
        emptyImage.symbolConfiguration = .init(pointSize: 28, weight: .regular)
        emptyImage.setAccessibilityElement(false)
        let emptyLabel = NSTextField(wrappingLabelWithString: emptyText)
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyState.orientation = .vertical
        emptyState.alignment = .centerX
        emptyState.spacing = 10
        emptyState.addArrangedSubview(emptyImage)
        emptyState.addArrangedSubview(emptyLabel)

        [header, group].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        [scrollView, emptyState].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            group.addSubview($0)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 7),
            countLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: addButton.leadingAnchor, constant: -8),
            addButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            group.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            group.leadingAnchor.constraint(equalTo: leadingAnchor),
            group.trailingAnchor.constraint(equalTo: trailingAnchor),
            group.heightAnchor.constraint(equalToConstant: 290),
            group.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.topAnchor.constraint(equalTo: group.topAnchor, constant: 1),
            scrollView.leadingAnchor.constraint(equalTo: group.leadingAnchor, constant: 1),
            scrollView.trailingAnchor.constraint(equalTo: group.trailingAnchor, constant: -1),
            scrollView.bottomAnchor.constraint(equalTo: group.bottomAnchor, constant: -1),
            rows.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            emptyState.centerXAnchor.constraint(equalTo: group.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: group.centerYAnchor),
            emptyState.widthAnchor.constraint(lessThanOrEqualTo: group.widthAnchor, constant: -48),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 230),
            emptyImage.widthAnchor.constraint(equalToConstant: 36),
            emptyImage.heightAnchor.constraint(equalToConstant: 36)
        ])
        update(identifiers: [])
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 326)
    }

    func update(identifiers: [String], inactive: Bool = false) {
        let focusedButton = window?.firstResponder as? ApplicationRuleActionButton
        let focusedIdentifier = focusedButton.flatMap { $0.isDescendant(of: self) ? $0.ruleIdentifier : nil }
        let focusedRowIndex = rows.arrangedSubviews.firstIndex { row in
            row.subviews.contains { ($0 as? ApplicationRuleActionButton)?.ruleIdentifier == focusedIdentifier && focusedIdentifier != nil }
        }
        countLabel.stringValue = inactive
            ? "\(identifiers.count) · \(localized("Selected mode only", "指定模式生效"))"
            : String(identifiers.count)
        let inactiveHelp = inactive
            ? localized("These rules apply in Selected Apps mode. You can edit them at any time.", "这些规则在指定 App 模式下生效，仍可随时编辑。")
            : nil
        countLabel.toolTip = inactiveHelp
        countLabel.setAccessibilityHelp(inactiveHelp)
        for row in rows.arrangedSubviews {
            rows.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        for (index, identifier) in identifiers.enumerated() {
            let row = makeRow(identifier: identifier, separator: index < identifiers.count - 1)
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        emptyState.isHidden = !identifiers.isEmpty
        scrollView.isHidden = identifiers.isEmpty
        if let focusedRowIndex {
            let index = focusedIdentifier.flatMap { identifiers.firstIndex(of: $0) }
                ?? min(focusedRowIndex, identifiers.count - 1)
            if identifiers.indices.contains(index),
               let button = rows.arrangedSubviews[index].subviews.compactMap({ $0 as? ApplicationRuleActionButton }).first {
                window?.makeFirstResponder(button)
                button.scrollToVisible(button.bounds)
            } else {
                window?.makeFirstResponder(addButton)
            }
        }
    }

    private func makeRow(identifier: String, separator: Bool) -> NSView {
        let presentation = ApplicationRulePresentation.resolve(identifier: identifier)
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.setAccessibilityIdentifier("\(accessibilityIdentifierPrefix).row.\(identifier)")
        row.toolTip = identifier

        let icon = NSImageView()
        icon.image = presentation.image
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.contentTintColor = presentation.isSymbol ? .secondaryLabelColor : nil
        icon.symbolConfiguration = .init(pointSize: 22, weight: .regular)
        icon.setAccessibilityElement(false)
        let name = NSTextField(labelWithString: presentation.name)
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = identifier
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let labels = NSStackView(views: [name])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        if let subtitle = presentation.subtitle {
            let detail = NSTextField(labelWithString: subtitle)
            detail.font = .systemFont(ofSize: 11)
            detail.textColor = .secondaryLabelColor
            detail.lineBreakMode = .byTruncatingTail
            detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            labels.addArrangedSubview(detail)
            detail.widthAnchor.constraint(lessThanOrEqualTo: labels.widthAnchor).isActive = true
        }
        name.widthAnchor.constraint(lessThanOrEqualTo: labels.widthAnchor).isActive = true

        let remove = ApplicationRuleActionButton()
        remove.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: nil)
        remove.imagePosition = .imageOnly
        remove.symbolConfiguration = .init(pointSize: 16, weight: .regular)
        remove.isBordered = false
        remove.bezelStyle = .inline
        remove.contentTintColor = .secondaryLabelColor
        remove.controlSize = .small
        remove.allowsDeleteKey = true
        remove.ruleIdentifier = identifier
        let removeLabel = "\(localized("Remove", "移除")) \(presentation.name)"
        remove.toolTip = removeLabel
        remove.setAccessibilityLabel(removeLabel)
        remove.setAccessibilityIdentifier("\(accessibilityIdentifierPrefix).remove.\(identifier)")
        remove.onAction = { [weak self] in self?.onRemove(identifier) }

        [icon, labels, remove].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 52),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            labels.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: remove.leadingAnchor, constant: -8),
            remove.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            remove.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            remove.widthAnchor.constraint(equalToConstant: 28),
            remove.heightAnchor.constraint(equalToConstant: 28)
        ])
        if separator {
            let line = NSBox()
            line.boxType = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(line)
            NSLayoutConstraint.activate([
                line.leadingAnchor.constraint(equalTo: labels.leadingAnchor),
                line.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
                line.bottomAnchor.constraint(equalTo: row.bottomAnchor)
            ])
        }
        return row
    }


    private func localized(_ english: String, _ chinese: String) -> String {
        FlowSoundLanguage.current == .simplifiedChinese ? chinese : english
    }
}

@MainActor
struct ApplicationRulePresentation {
    let name: String
    let subtitle: String?
    let image: NSImage?
    let isSymbol: Bool

    static func resolve(identifier: String) -> ApplicationRulePresentation {
        let system: (String, String)? = switch identifier {
        case "com.apple.usernoted": (localized("Notifications", "系统通知"), "bell.badge")
        case "com.apple.notificationcenterui": (localized("Notification Center", "通知中心"), "bell")
        case "systemsoundserverd": (localized("System Sounds", "系统提示音"), "speaker.wave.2")
        default: nil
        }
        if let (name, symbol) = system {
            return .init(name: name, subtitle: localized("System", "系统"), image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil), isSymbol: true)
        }
        let safariHelper = FlowSoundSettings.safariAudioBundleIdentifiers.contains(identifier) && identifier != "com.apple.Safari"
        let musicHelper = identifier.hasPrefix("com.apple.Music.") || identifier.hasPrefix("com.apple.iTunes.")
        let telegramHelper = identifier.hasPrefix("ru.keepcoder.Telegram.") || identifier.hasPrefix("org.telegram.desktop.")
        if safariHelper || musicHelper || telegramHelper {
            let name = musicHelper ? localized("Music", "音乐") : (telegramHelper ? "Telegram" : "Safari")
            return .init(name: name, subtitle: localized("Helper process", "辅助进程"), image: NSImage(systemSymbolName: "app.connected.to.app.below.fill", accessibilityDescription: nil), isSymbol: true)
        }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        if let url {
            let displayName = FileManager.default.displayName(atPath: url.path)
            let name = displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
            return .init(name: name, subtitle: nil, image: NSWorkspace.shared.icon(forFile: url.path), isSymbol: false)
        }
        let knownName: String? = switch identifier {
        case "com.apple.Safari": "Safari"
        case "ru.keepcoder.Telegram", "org.telegram.desktop": "Telegram"
        case "com.apple.Music": localized("Music", "音乐")
        case "com.apple.iTunes": "iTunes"
        case "com.spotify.client": "Spotify"
        case "com.netease.163music": localized("NetEase Cloud Music", "网易云音乐")
        case "com.flowsound.FlowSound": "FlowSound"
        default: nil
        }
        let lastComponent = identifier.split(separator: ".").last.map(String.init) ?? identifier
        let fallbackName = lastComponent.prefix(1).uppercased() + lastComponent.dropFirst()
        return .init(
            name: knownName ?? fallbackName,
            subtitle: localized("Not installed", "未安装"),
            image: NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil),
            isSymbol: true
        )
    }


    private static func localized(_ english: String, _ chinese: String) -> String {
        FlowSoundLanguage.current == .simplifiedChinese ? chinese : english
    }
}

@MainActor
private final class ApplicationRuleActionButton: NSButton {
    var onAction: (() -> Void)?
    var allowsDeleteKey = false
    var ruleIdentifier: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(performAction)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override var alignmentRectInsets: NSEdgeInsets {
        allowsDeleteKey ? NSEdgeInsetsZero : super.alignmentRectInsets
    }

    override func keyDown(with event: NSEvent) {
        let hasShortcutModifier = !event.modifierFlags.intersection([.command, .option, .control]).isEmpty
        if allowsDeleteKey, !hasShortcutModifier, event.keyCode == 51 || event.keyCode == 117 {
            performClick(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    @objc private func performAction() { onAction?() }
}

@MainActor
private final class ApplicationRuleListView: NSStackView {
    override var isFlipped: Bool { true }
}

/// Use semantic colors at drawing time so appearance and increased contrast changes stay native.
@MainActor
private final class ApplicationRuleGroupView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        NSColor.controlBackgroundColor.setFill()
        outline.fill()
        NSColor.separatorColor.setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }
}
