import AppKit
import ApplicationServices
import Combine
import Foundation

/// Abstraction over the macOS Accessibility trust APIs so the service can be unit tested.
protocol AccessibilityPermissionChecking {
    func isTrusted() -> Bool
    /// Ask macOS to show its "grant accessibility access" prompt; returns the current trust state.
    @discardableResult func promptForTrust() -> Bool
    func openSystemSettings()
}

/// Production checker backed by `AXIsProcessTrusted` and System Settings deep links.
struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func promptForTrust() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(AccessibilityPermissionService.systemSettingsURL)
    }
}

/// Checker that never touches the Accessibility API. Used when the app runs as a unit-test host:
/// macOS keys Accessibility (TCC) rows by bundle ID and stores the code requirement of the first
/// process that asked, so an ad-hoc-signed test host asking would poison the row for the real app.
struct DeniedAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    func isTrusted() -> Bool { false }
    @discardableResult func promptForTrust() -> Bool { false }
    func openSystemSettings() {}
}

/// Observable source of truth for the app's Accessibility permission.
///
/// The service reads the trust state on demand (`refresh()`), can trigger the system prompt
/// (`requestAccess()`), deep-links to System Settings, and can poll while access is missing
/// so the rest of the app reacts as soon as the user flips the switch.
@MainActor
final class AccessibilityPermissionService: ObservableObject {
    nonisolated static let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    @Published private(set) var isGranted: Bool
    @Published private(set) var lastCheckedAt: Date?

    private let checker: AccessibilityPermissionChecking
    private let pollingInterval: TimeInterval
    private var pollingTimer: Timer?
    /// Set by `startMonitoring()`; lets polling resume automatically if access is revoked later.
    private var wantsMonitoring = false
    private var activationSubscription: AnyCancellable?

    var isMonitoring: Bool {
        pollingTimer != nil
    }

    var statusTitle: String {
        isGranted ? "Accessibility access granted" : "Accessibility access required"
    }

    var statusDetail: String {
        if isGranted {
            return "ButlerAI can detect the keyboard shortcut and replace the selected text in any app."
        }
        return "ButlerAI needs Accessibility access to detect the keyboard shortcut and replace the selected text; enable ButlerAI under Privacy & Security › Accessibility in System Settings."
    }

    init(checker: AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
         pollingInterval: TimeInterval = 2.0) {
        self.checker = checker
        self.pollingInterval = pollingInterval
        self.isGranted = checker.isTrusted()
        self.lastCheckedAt = Date()

        // Users typically toggle the switch in System Settings and then come back to the app.
        activationSubscription = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }

        log("Accessibility permission service initialized (granted: \(isGranted))")
    }

    deinit {
        pollingTimer?.invalidate()
    }

    /// Re-reads the trust state. Publishes `isGranted` only when it actually changed.
    func refresh() {
        lastCheckedAt = Date()
        applyTrustState(checker.isTrusted())
    }

    /// Timer-driven check: like `refresh()` but without touching `lastCheckedAt`, so a 2s poll
    /// does not re-render every observing view.
    private func poll() {
        applyTrustState(checker.isTrusted())
    }

    private func applyTrustState(_ trusted: Bool) {
        guard trusted != isGranted else { return }

        isGranted = trusted
        if trusted {
            log("Accessibility permission granted")
            invalidatePollingTimer()
        } else {
            log("Accessibility permission missing", type: .warning)
            if wantsMonitoring {
                schedulePollingTimer()
            }
        }
    }

    /// Shows the macOS Accessibility prompt (if the system decides to show it) and refreshes.
    func requestAccess() {
        log("Requesting accessibility access from macOS")
        checker.promptForTrust()
        refresh()
    }

    func openSystemSettings() {
        log("Opening System Settings › Privacy & Security › Accessibility")
        checker.openSystemSettings()
    }

    /// Polls the trust state every `pollingInterval` seconds while access is missing.
    /// Pauses automatically once access is granted and resumes if it is revoked again.
    /// Safe to call repeatedly.
    func startMonitoring() {
        wantsMonitoring = true
        guard !isMonitoring else { return }
        refresh()
        guard !isGranted else { return }
        schedulePollingTimer()
    }

    func stopMonitoring() {
        wantsMonitoring = false
        invalidatePollingTimer()
    }

    private func schedulePollingTimer() {
        guard pollingTimer == nil else { return }
        let timer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
        log("Started polling accessibility permission every \(pollingInterval)s")
    }

    private func invalidatePollingTimer() {
        guard let pollingTimer else { return }
        pollingTimer.invalidate()
        self.pollingTimer = nil
        log("Stopped polling accessibility permission")
    }
}
