import AppKit

class ClipboardManager {
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
    
    private let pasteboard = NSPasteboard.general
    private var previousContent: String?
    
    func getSelectedText() throws -> String {
        // Save current clipboard content
        previousContent = pasteboard.string(forType: .string)
        
        // Simulate copy command
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the clipboard to update
        Thread.sleep(forTimeInterval: 0.1)
        
        guard let selectedText = pasteboard.string(forType: .string) else {
            // Restore previous clipboard content
            if let previous = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
            throw ClipboardError.noTextSelected
        }
        
        return selectedText
    }
    
    func replaceSelectedText(with newText: String) throws {
        // Store new text in clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        // Simulate paste command
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the paste to complete
        Thread.sleep(forTimeInterval: 0.1)
        
        // Restore previous clipboard content
        if let previous = previousContent {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }
}
