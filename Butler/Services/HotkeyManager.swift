import Foundation
import Carbon
import AppKit

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        registerHotkey()
    }
    
    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
    
    private func registerHotkey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        // Create handler
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerCallback: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )
            
            guard status == noErr else { return status }
            
            if hotkeyID.id == 1 {
                let selfObject = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                DispatchQueue.main.async {
                    selfObject.callback()
                }
            }
            
            return noErr
        }
        
        // Install handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        // Register hotkey (Control + Option + Command + C)
        var hotkeyID = EventHotKeyID(signature: OSType(0x4275746C), // "Butl"
                                    id: 1)
        var hotKeyRef: EventHotKeyRef?
        
        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(controlKey | optionKey | cmdKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
