import AppKit
import ClipboardCore
import SwiftUI

/// AppKit tab strip — SwiftUI `.plain` buttons are unreliable in a
/// nonactivating `NSPanel` (hits fall through transparent hosting regions).
struct PanelModeTabBar: NSViewRepresentable {
    @ObservedObject var session: PanelSessionModel

    func makeNSView(context: Context) -> PanelModeTabBarView {
        let view = PanelModeTabBarView()
        view.onSelect = { [weak session] mode in
            session?.mode = mode
        }
        view.refresh(selected: session.mode)
        return view
    }

    func updateNSView(_ nsView: PanelModeTabBarView, context: Context) {
        nsView.onSelect = { [weak session] mode in
            session?.mode = mode
        }
        nsView.refresh(selected: session.mode)
    }
}

final class PanelModeTabBarView: NSView {
    var onSelect: ((PanelMode) -> Void)?

    private var buttons: [PanelMode: NSButton] = [:]
    private let stack = NSStackView()
    private let separator = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear

        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: separator.topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
        ])

        for mode in PanelMode.allCases {
            let button = makeButton(for: mode)
            buttons[mode] = button
            stack.addArrangedSubview(button)
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func refresh(selected: PanelMode) {
        for (mode, button) in buttons {
            let isSelected = mode == selected
            button.contentTintColor = isSelected ? .controlAccentColor : .secondaryLabelColor
            button.tag = isSelected ? 1 : 0
            if let cell = button.cell as? NSButtonCell {
                cell.backgroundColor = .clear
            }
            button.layer?.backgroundColor = NSColor.clear.cgColor
            // Underline via attributed border view
            button.layer?.sublayers?
                .first { $0.name == "underline" }?
                .backgroundColor = (isSelected ? NSColor.controlAccentColor : .clear).cgColor
        }
    }

    private func makeButton(for mode: PanelMode) -> NSButton {
        let button = FirstMouseButton(frame: NSRect(x: 0, y: 0, width: 44, height: 32))
        button.image = NSImage(systemSymbolName: mode.systemImage, accessibilityDescription: mode.title)
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.bezelStyle = .inline
        button.isBordered = false
        button.focusRingType = .none
        button.toolTip = mode.title
        button.setAccessibilityLabel(mode.title)
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = #selector(tabClicked(_:))
        button.identifier = NSUserInterfaceItemIdentifier(mode.rawValue)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])

        button.wantsLayer = true
        let underline = CALayer()
        underline.name = "underline"
        underline.backgroundColor = NSColor.clear.cgColor
        underline.cornerRadius = 1
        underline.frame = CGRect(x: 11, y: 2, width: 22, height: 2)
        button.layer?.addSublayer(underline)

        return button
    }

    @objc private func tabClicked(_ sender: NSButton) {
        guard
            let raw = sender.identifier?.rawValue,
            let mode = PanelMode(rawValue: raw)
        else { return }
        onSelect?(mode)
    }

    override func layout() {
        super.layout()
        for button in buttons.values {
            button.layer?.sublayers?
                .first { $0.name == "underline" }?
                .frame = CGRect(x: (button.bounds.width - 22) / 2, y: 2, width: 22, height: 2)
        }
    }
}

/// NSButton that activates on the first click in a nonactivating panel.
private final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
