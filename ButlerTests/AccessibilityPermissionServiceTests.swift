import AppKit
import Combine
import XCTest
@testable import Butler

final class FakeAccessibilityChecker: AccessibilityPermissionChecking {
    var trusted: Bool
    /// When true, `promptForTrust()` simulates the user granting access from the system prompt.
    var grantsOnPrompt = false
    private(set) var promptCount = 0
    private(set) var openSettingsCount = 0

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func isTrusted() -> Bool {
        trusted
    }

    @discardableResult
    func promptForTrust() -> Bool {
        promptCount += 1
        if grantsOnPrompt {
            trusted = true
        }
        return trusted
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }
}

@MainActor
final class AccessibilityPermissionServiceTests: XCTestCase {
    func testInitialStateReflectsChecker() {
        XCTAssertTrue(AccessibilityPermissionService(checker: FakeAccessibilityChecker(trusted: true)).isGranted)
        XCTAssertFalse(AccessibilityPermissionService(checker: FakeAccessibilityChecker(trusted: false)).isGranted)
    }

    func testRefreshPicksUpChangesAndUpdatesLastChecked() {
        let checker = FakeAccessibilityChecker(trusted: false)
        let service = AccessibilityPermissionService(checker: checker)
        let initialCheck = service.lastCheckedAt
        XCTAssertNotNil(initialCheck)

        checker.trusted = true
        service.refresh()

        XCTAssertTrue(service.isGranted)
        XCTAssertNotNil(service.lastCheckedAt)
        XCTAssertGreaterThanOrEqual(service.lastCheckedAt!, initialCheck!)

        checker.trusted = false
        service.refresh()
        XCTAssertFalse(service.isGranted)
    }

    func testRequestAccessPromptsOnceAndRefreshes() {
        let checker = FakeAccessibilityChecker(trusted: false)
        checker.grantsOnPrompt = true
        let service = AccessibilityPermissionService(checker: checker)

        service.requestAccess()

        XCTAssertEqual(checker.promptCount, 1)
        XCTAssertTrue(service.isGranted)
    }

    func testOpenSystemSettingsDelegatesToChecker() {
        let checker = FakeAccessibilityChecker(trusted: false)
        let service = AccessibilityPermissionService(checker: checker)

        service.openSystemSettings()

        XCTAssertEqual(checker.openSettingsCount, 1)
    }

    func testMonitoringDetectsGrantAndStopsItself() async {
        let checker = FakeAccessibilityChecker(trusted: false)
        let service = AccessibilityPermissionService(checker: checker, pollingInterval: 0.05)

        service.startMonitoring()
        XCTAssertTrue(service.isMonitoring)

        let granted = expectation(description: "isGranted becomes true")
        let subscription = service.$isGranted
            .dropFirst()
            .filter { $0 }
            .sink { _ in granted.fulfill() }
        defer { subscription.cancel() }

        checker.trusted = true
        await fulfillment(of: [granted], timeout: 2)

        XCTAssertTrue(service.isGranted)
        XCTAssertFalse(service.isMonitoring)
    }

    func testStartMonitoringIsNoOpWhenAlreadyGranted() {
        let service = AccessibilityPermissionService(checker: FakeAccessibilityChecker(trusted: true), pollingInterval: 0.05)

        service.startMonitoring()

        XCTAssertFalse(service.isMonitoring)
    }

    func testStartMonitoringIsIdempotentAndStopMonitoringStops() {
        let service = AccessibilityPermissionService(checker: FakeAccessibilityChecker(trusted: false), pollingInterval: 10)

        service.startMonitoring()
        service.startMonitoring()
        XCTAssertTrue(service.isMonitoring)

        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)

        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)
    }

    func testMonitoringResumesWhenAccessIsRevoked() {
        let checker = FakeAccessibilityChecker(trusted: true)
        let service = AccessibilityPermissionService(checker: checker, pollingInterval: 10)

        service.startMonitoring()
        XCTAssertFalse(service.isMonitoring, "Nothing to poll while access is granted")

        checker.trusted = false
        service.refresh()
        XCTAssertFalse(service.isGranted)
        XCTAssertTrue(service.isMonitoring, "Polling must resume after a revocation")

        checker.trusted = true
        service.refresh()
        XCTAssertTrue(service.isGranted)
        XCTAssertFalse(service.isMonitoring)
    }

    func testStopMonitoringPreventsAutomaticResume() {
        let checker = FakeAccessibilityChecker(trusted: true)
        let service = AccessibilityPermissionService(checker: checker, pollingInterval: 10)

        service.startMonitoring()
        service.stopMonitoring()

        checker.trusted = false
        service.refresh()

        XCTAssertFalse(service.isMonitoring)
    }

    func testStatusTitleAndDetailChangeWithState() {
        let checker = FakeAccessibilityChecker(trusted: false)
        let service = AccessibilityPermissionService(checker: checker)

        XCTAssertEqual(service.statusTitle, "Accessibility access required")
        XCTAssertTrue(service.statusDetail.contains("System Settings"))

        checker.trusted = true
        service.refresh()

        XCTAssertEqual(service.statusTitle, "Accessibility access granted")
        XCTAssertFalse(service.statusDetail.contains("System Settings"))
    }
}

final class KeyboardShortcutSpecTests: XCTestCase {
    private func keyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isARepeat: Bool = false) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "c",
            charactersIgnoringModifiers: "c",
            isARepeat: isARepeat,
            keyCode: keyCode
        )!
    }

    func testShortcutRejectsExtraModifiersAndKeyRepeats() {
        let shortcut = HotkeyManager.improveTextShortcut
        XCTAssertFalse(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [.control, .option, .command, .shift])))
        XCTAssertFalse(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [.control, .option, .command], isARepeat: true)))
    }

    func testImproveTextShortcutMatchesControlOptionCommandC() {
        let shortcut = HotkeyManager.improveTextShortcut
        XCTAssertEqual(shortcut.displayString, "⌃⌥⌘C")
        XCTAssertTrue(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [.control, .option, .command])))
    }

    func testShortcutIgnoresCapsLockAndFunctionNoise() {
        let shortcut = HotkeyManager.improveTextShortcut
        XCTAssertTrue(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [.control, .option, .command, .capsLock])))
        XCTAssertTrue(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [.control, .option, .command, .function])))
    }

    func testShortcutRequiresAllModifiersAndKeyCode() {
        let shortcut = HotkeyManager.improveTextShortcut
        XCTAssertFalse(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [.control, .command])))
        XCTAssertFalse(shortcut.matches(keyDown(keyCode: 0x08, modifiers: [])))
        XCTAssertFalse(shortcut.matches(keyDown(keyCode: 0x09, modifiers: [.control, .option, .command])))
    }
}
