import AppKit

/// Snapshot of every item currently on a pasteboard so it can be restored later.
struct PasteboardSnapshot {
    let itemData: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        self.itemData = pasteboard.pasteboardItems?.map { item in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataByType[type] = data
                }
            }
            return dataByType
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !itemData.isEmpty else { return }
        let items = itemData.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}

/// Abstraction over posting synthetic keyboard events so the clipboard flow can be unit tested.
protocol KeystrokeSimulating {
    func simulateKeystroke(keyCode: CGKeyCode, flags: CGEventFlags)
}

/// Posts key-down/key-up pairs to the HID event tap. Requires Accessibility permission at runtime.
struct CGEventKeystrokeSimulator: KeystrokeSimulating {
    func simulateKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .privateState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            log("Failed to create keyboard events for keyCode \(keyCode)", type: .error)
            return
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

/// Captures the current selection via a simulated ⌘C, pastes replacement text via ⌘V,
/// and preserves whatever the user had on the clipboard before.
final class ClipboardManager {
    enum ClipboardError: LocalizedError {
        case noTextSelected
        case textReplacementFailed

        var errorDescription: String? {
            switch self {
            case .noTextSelected:
                return "No text selected"
            case .textReplacementFailed:
                return "Failed to replace selected text"
            }
        }
    }

    static let copyKeyCode: CGKeyCode = 0x08   // 'c'
    static let pasteKeyCode: CGKeyCode = 0x09  // 'v'

    private let pasteboard: NSPasteboard
    private let keystrokes: KeystrokeSimulating
    private let copyTimeout: TimeInterval
    private let pasteSettleDelay: TimeInterval
    private let pollInterval: TimeInterval
    private var previousSnapshot: PasteboardSnapshot?

    init(
        pasteboard: NSPasteboard = .general,
        keystrokes: KeystrokeSimulating = CGEventKeystrokeSimulator(),
        copyTimeout: TimeInterval = 0.5,
        pasteSettleDelay: TimeInterval = 0.3,
        pollInterval: TimeInterval = 0.05
    ) {
        self.pasteboard = pasteboard
        self.keystrokes = keystrokes
        self.copyTimeout = copyTimeout
        self.pasteSettleDelay = pasteSettleDelay
        self.pollInterval = pollInterval
    }

    /// Copies the current selection and returns it. The previous clipboard contents are
    /// remembered until `replaceSelectedText(with:)` or `restorePreviousClipboard()` is called.
    func getSelectedText() async throws -> String {
        log("Attempting to get selected text")

        previousSnapshot = PasteboardSnapshot(pasteboard: pasteboard)
        log("Saved previous clipboard content")

        let initialChangeCount = pasteboard.changeCount

        log("Simulating CMD+C to capture selection")
        keystrokes.simulateKeystroke(keyCode: Self.copyKeyCode, flags: .maskCommand)

        let updated = await waitForPasteboardChange(from: initialChangeCount, timeout: copyTimeout)
        guard updated else {
            // Nothing was copied: the pasteboard still holds the *old* clipboard content,
            // which must not be mistaken for a selection.
            log("Pasteboard did not update after copy; assuming no selection", type: .warning)
            previousSnapshot = nil // the pasteboard is untouched; nothing to restore
            throw ClipboardError.noTextSelected
        }

        guard let selectedText = pasteboard.string(forType: .string),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log("No text found in clipboard", type: .warning)
            restorePreviousClipboard()
            throw ClipboardError.noTextSelected
        }

        log("Successfully captured text: \(selectedText.prefix(50))...")
        return selectedText
    }

    /// Pastes `newText` over the current selection, then restores the previous clipboard contents.
    func replaceSelectedText(with newText: String) async throws {
        log("Attempting to replace text with new content (length: \(newText.count))")

        pasteboard.clearContents()
        guard pasteboard.setString(newText, forType: .string) else {
            log("Failed to write improved text to the pasteboard", type: .error)
            restorePreviousClipboard()
            throw ClipboardError.textReplacementFailed
        }
        log("New text stored in clipboard")

        log("Simulating CMD+V to paste improved text")
        keystrokes.simulateKeystroke(keyCode: Self.pasteKeyCode, flags: .maskCommand)

        // Give the target application time to service the ⌘V before the pasteboard is restored;
        // restoring too early would paste the *old* clipboard into slow apps.
        try await Task.sleep(nanoseconds: UInt64(pasteSettleDelay * 1_000_000_000))

        restorePreviousClipboard()
        log("Text replacement complete")
    }

    /// Restores the clipboard captured by the last `getSelectedText()` call, if any.
    /// Safe to call multiple times; call it when the improvement flow fails mid-way.
    func restorePreviousClipboard() {
        guard let snapshot = previousSnapshot else { return }
        snapshot.restore(to: pasteboard)
        previousSnapshot = nil
        log("Restored previous clipboard content")
    }

    private func waitForPasteboardChange(from initialChangeCount: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != initialChangeCount {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return pasteboard.changeCount != initialChangeCount
    }
}
