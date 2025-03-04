import Foundation
import Carbon
import AppKit

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var monitorEvent: Any?
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        registerHotkey()
    }
    
    deinit {
        print("Cleaning up HotkeyManager")
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        if let monitor = monitorEvent {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func registerHotkey() {
        print("Registering global hotkey ⌃⌥⌘C")
        
        // Request accessibility permissions if needed
        if !AXIsProcessTrusted() {
            print("Warning: App is not trusted for accessibility")
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        } else {
            print("App is trusted for accessibility")
        }
        
        // Set up monitoring of global keyboard events
        monitorEvent = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else {
                print("Warning: Self is nil in hotkey handler")
                return
            }
            
            if event.modifierFlags.contains([.control, .option, .command]) &&
               event.keyCode == 0x08 { // 'c' key
                print("Global keyboard shortcut ⌃⌥⌘C detected")
                DispatchQueue.main.async {
                    self.callback()
                }
            }
        }
        
        if monitorEvent == nil {
            print("Error: Failed to register global monitor")
        } else {
            print("Global keyboard monitor registered successfully")
        }
        
        print("Hotkey registration complete")
    }
}
