import AppKit
import XCTest
@testable import Butler

/// Fake keystroke simulator that mutates a pasteboard the way a real ⌘C / ⌘V would.
private final class FakeKeystrokeSimulator: KeystrokeSimulating {
    let pasteboard: NSPasteboard
    /// Text that ⌘C "copies" into the pasteboard; `nil` simulates an empty selection.
    var copiedText: String?
    private(set) var keystrokes: [(keyCode: CGKeyCode, flags: CGEventFlags)] = []
    private(set) var pastedText: String?

    init(pasteboard: NSPasteboard, copiedText: String?) {
        self.pasteboard = pasteboard
        self.copiedText = copiedText
    }

    func simulateKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        keystrokes.append((keyCode, flags))
        switch keyCode {
        case ClipboardManager.copyKeyCode:
            if let copiedText {
                pasteboard.clearContents()
                pasteboard.setString(copiedText, forType: .string)
            }
        case ClipboardManager.pasteKeyCode:
            pastedText = pasteboard.string(forType: .string)
        default:
            break
        }
    }
}

final class ClipboardManagerTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name("ButlerTests.ClipboardManager.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("Original clipboard", forType: .string)
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    private func makeManager(copiedText: String?) -> (ClipboardManager, FakeKeystrokeSimulator) {
        let simulator = FakeKeystrokeSimulator(pasteboard: pasteboard, copiedText: copiedText)
        let manager = ClipboardManager(
            pasteboard: pasteboard,
            keystrokes: simulator,
            copyTimeout: 0.2,
            pasteSettleDelay: 0.01,
            pollInterval: 0.005
        )
        return (manager, simulator)
    }

    func testGetSelectedTextReturnsCopiedSelection() async throws {
        let (manager, simulator) = makeManager(copiedText: "Selected words")

        let text = try await manager.getSelectedText()

        XCTAssertEqual(text, "Selected words")
        XCTAssertEqual(simulator.keystrokes.count, 1)
        XCTAssertEqual(simulator.keystrokes.first?.keyCode, ClipboardManager.copyKeyCode)
        XCTAssertEqual(simulator.keystrokes.first?.flags, .maskCommand)
    }

    func testGetSelectedTextThrowsAndRestoresClipboardWhenNothingWasCopied() async {
        let (manager, _) = makeManager(copiedText: nil)

        do {
            _ = try await manager.getSelectedText()
            XCTFail("Expected noTextSelected")
        } catch let error as ClipboardManager.ClipboardError {
            XCTAssertEqual(error, .noTextSelected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(pasteboard.string(forType: .string), "Original clipboard")
    }

    func testGetSelectedTextThrowsForWhitespaceOnlySelection() async {
        let (manager, _) = makeManager(copiedText: "   \n")

        do {
            _ = try await manager.getSelectedText()
            XCTFail("Expected noTextSelected")
        } catch let error as ClipboardManager.ClipboardError {
            XCTAssertEqual(error, .noTextSelected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(pasteboard.string(forType: .string), "Original clipboard")
    }

    func testReplaceSelectedTextPastesNewTextThenRestoresClipboard() async throws {
        let (manager, simulator) = makeManager(copiedText: "Selected words")
        _ = try await manager.getSelectedText()

        try await manager.replaceSelectedText(with: "Improved words")

        XCTAssertEqual(simulator.pastedText, "Improved words")
        XCTAssertEqual(simulator.keystrokes.last?.keyCode, ClipboardManager.pasteKeyCode)
        XCTAssertEqual(pasteboard.string(forType: .string), "Original clipboard")
    }

    func testRestorePreviousClipboardAfterFailedImprovement() async throws {
        let (manager, _) = makeManager(copiedText: "Selected words")
        _ = try await manager.getSelectedText()
        XCTAssertEqual(pasteboard.string(forType: .string), "Selected words")

        manager.restorePreviousClipboard()

        XCTAssertEqual(pasteboard.string(forType: .string), "Original clipboard")
    }

    func testRestorePreviousClipboardIsIdempotent() async throws {
        let (manager, _) = makeManager(copiedText: "Selected words")
        _ = try await manager.getSelectedText()

        manager.restorePreviousClipboard()
        pasteboard.clearContents()
        pasteboard.setString("Something newer", forType: .string)
        manager.restorePreviousClipboard()

        XCTAssertEqual(pasteboard.string(forType: .string), "Something newer")
    }
}
