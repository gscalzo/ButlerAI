import AppKit
import XCTest
@testable import Butler

final class PasteboardSnapshotTests: XCTestCase {
    func testPasteboardSnapshotRestoresString() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ButlerTests.PasteboardSnapshot.Restore\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("Original", forType: .string)

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("New", forType: .string)

        snapshot.restore(to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "Original")
    }

    func testPasteboardSnapshotRestoresEmptyState() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ButlerTests.PasteboardSnapshot.Empty\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.setString("Temp", forType: .string)
        snapshot.restore(to: pasteboard)

        XCTAssertNil(pasteboard.string(forType: .string))
    }
}
