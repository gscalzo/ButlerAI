import AppKit
import Combine

/// Describes a global keyboard shortcut in one place so the hotkey monitor and the UI agree.
struct KeyboardShortcutSpec: Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let displayString: String

    /// The ⌃⌥⌘C shortcut that triggers "Improve Selected Text".
    static let improveText = KeyboardShortcutSpec(
        keyCode: 0x08, // 'c'
        modifiers: [.control, .option, .command],
        displayString: "⌃⌥⌘C"
    )

    /// True when the event carries this key code and exactly the required modifiers (⇧⌃⌥⌘C is a
    /// different chord). Device-dependent bits and Caps Lock / Fn / keypad noise are ignored, and
    /// key-repeat events never match so holding the chord triggers once.
    func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == keyCode, !event.isARepeat else { return false }
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad, .help])
        return flags == modifiers
    }
}

/// Registers a global key-down monitor for the improve-text shortcut whenever Accessibility
/// access is available, and removes it when access is revoked.
@MainActor
final class HotkeyManager: ObservableObject {
    nonisolated static let improveTextShortcut = KeyboardShortcutSpec.improveText

    @Published private(set) var isRegistered = false

    private let permissionService: AccessibilityPermissionService
    private let shortcut: KeyboardShortcutSpec
    private let callback: () -> Void
    private var monitor: Any?
    private var permissionSubscription: AnyCancellable?

    init(permissionService: AccessibilityPermissionService,
         shortcut: KeyboardShortcutSpec = HotkeyManager.improveTextShortcut,
         callback: @escaping () -> Void) {
        self.permissionService = permissionService
        self.shortcut = shortcut
        self.callback = callback
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Follows the permission state: registers the monitor when granted, removes it when revoked.
    func start() {
        guard permissionSubscription == nil else { return }
        log("Starting hotkey manager for \(shortcut.displayString)")
        permissionSubscription = permissionService.$isGranted
            .removeDuplicates()
            .sink { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.registerMonitor()
                } else {
                    self.unregisterMonitor()
                }
            }
    }

    func stop() {
        permissionSubscription?.cancel()
        permissionSubscription = nil
        unregisterMonitor()
    }

    private func registerMonitor() {
        guard monitor == nil else { return }
        log("Registering global hotkey \(shortcut.displayString)")

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.shortcut.matches(event) else { return }
                log("Global keyboard shortcut \(self.shortcut.displayString) detected")
                self.callback()
            }
        }

        isRegistered = monitor != nil
        if isRegistered {
            log("Global keyboard monitor registered successfully")
        } else {
            log("Error: Failed to register global monitor", type: .error)
        }
    }

    private func unregisterMonitor() {
        guard let monitor else {
            isRegistered = false
            return
        }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        isRegistered = false
        log("Global keyboard monitor removed (accessibility access unavailable)", type: .warning)
    }
}
