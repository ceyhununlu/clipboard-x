import Foundation

/// The pasteboard, as the monitor sees it.
public protocol PasteboardSource: AnyObject {
    /// Increments on every change made by any process.
    var changeCount: Int { get }
    /// The current contents, or `nil` when nothing usable is on the pasteboard.
    func readContent() -> ClipboardContent?
}

/// Watches a pasteboard for changes and reports new content.
///
/// macOS has no change notification for the pasteboard, so this polls the cheap
/// `changeCount` and only reads data when it moves.
@MainActor
public final class ClipboardMonitor {
    public nonisolated static let defaultInterval: TimeInterval = 0.35

    private let source: PasteboardSource
    private let interval: TimeInterval
    private let onChange: (ClipboardContent) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int

    public private(set) var isRunning = false

    public init(
        source: PasteboardSource,
        interval: TimeInterval = defaultInterval,
        onChange: @escaping (ClipboardContent) -> Void
    ) {
        self.source = source
        self.interval = interval
        self.onChange = onChange
        self.lastChangeCount = source.changeCount
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        // Common mode keeps polling while menus and panels are tracking events.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// One polling tick. Called by the timer, and directly by tests.
    public func poll() {
        let current = source.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard let content = source.readContent() else { return }
        onChange(content)
    }

    /// Marks the current pasteboard state as already seen.
    ///
    /// Called right after the app itself writes to the pasteboard so that
    /// pasting from history does not re-record and reorder the item.
    public func acknowledgeSelfWrite() {
        lastChangeCount = source.changeCount
    }
}
