import Foundation
import Carbon
import AppKit
import OSLog

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var monitorEvent: Any?
    private let callback: () -> Void
    private let logger = Logger(subsystem: "com.butler.app", category: "hotkey")
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        registerHotkey()
    }
    
    deinit {
        logger.info("HotkeyManager deinit")
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        if let monitor = monitorEvent {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func registerHotkey() {
        logger.info("Starting hotkey registration")
        
        // Request accessibility permissions if needed
        if !AXIsProcessTrusted() {
            logger.warning("App is not trusted for accessibility")
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        } else {
            logger.info("App is trusted for accessibility")
        }
        
        // Set up monitoring of global keyboard events
        monitorEvent = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            if event.modifierFlags.contains([.control, .option, .command]) &&
               event.keyCode == 0x08 { // 'c' key
                self.logger.info("Global keyboard shortcut detected")
                DispatchQueue.main.async {
                    self.callback()
                }
            }
        }
        
        logger.info("Global event monitor setup complete")
    }
}
