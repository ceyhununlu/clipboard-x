import AppKit
import ClipboardCore
import SwiftUI

/// Click to record, then press the shortcut you want.
///
/// Backed by AppKit because a shortcut recorder has to intercept key
/// equivalents such as ⌘V before the menu system claims them, which SwiftUI
/// does not expose.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var combo: KeyCombo
    var errorText: String?

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.combo = combo
        view.onChange = { newValue in combo = newValue }
        return view
    }

    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        view.combo = combo
        view.hasError = errorText != nil
        view.onChange = { newValue in combo = newValue }
    }

    @available(macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ShortcutRecorderView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 120, height: 24)
    }
}

final class ShortcutRecorderView: NSView {
    var onChange: (KeyCombo) -> Void = { _ in }

    var combo: KeyCombo = .openHistoryDefault {
        didSet { refresh() }
    }

    var hasError = false {
        didSet { refresh() }
    }

    private var isRecording = false {
        didSet { refresh() }
    }

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(greaterThanOrEqualTo: label.widthAnchor, constant: 16),
        ])
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: max(110, label.intrinsicContentSize.width + 20), height: 24)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    /// Shortcuts that are also menu key equivalents never reach `keyDown`, so
    /// recording has to happen here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        return record(event)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if !record(event) {
            NSSound.beep()
        }
    }

    private func record(_ event: NSEvent) -> Bool {
        if event.keyCode == VirtualKey.escape {
            isRecording = false
            window?.makeFirstResponder(nil)
            return true
        }

        let candidate = KeyCombo.from(
            keyCode: event.keyCode,
            cocoaModifierFlags: event.modifierFlags
                .intersection(.deviceIndependentFlagsMask).rawValue
        )
        guard candidate.isValid else { return false }

        combo = candidate
        onChange(candidate)
        isRecording = false
        window?.makeFirstResponder(nil)
        return true
    }

    private func refresh() {
        label.stringValue = isRecording ? "Press keys…" : combo.displayString
        label.textColor = isRecording ? .secondaryLabelColor : .labelColor
        layer?.backgroundColor = (isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.12)
            : NSColor.controlBackgroundColor).cgColor
        let border: NSColor = if isRecording {
            .controlAccentColor
        } else if hasError {
            .systemRed
        } else {
            .separatorColor
        }
        layer?.borderColor = border.cgColor
        invalidateIntrinsicContentSize()
        setAccessibilityLabel("Shortcut: \(combo.displayString)")
    }
}
