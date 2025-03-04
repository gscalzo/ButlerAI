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
        print("Attempting to get selected text")
        
        // Save current clipboard content
        previousContent = pasteboard.string(forType: .string)
        print("Saved previous clipboard content: \(previousContent?.prefix(20) ?? "none")")
        
        // Simulate copy command
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        print("Simulating CMD+C to capture selection")
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the clipboard to update
        Thread.sleep(forTimeInterval: 0.1)
        
        guard let selectedText = pasteboard.string(forType: .string) else {
            print("No text found in clipboard")
            // Restore previous clipboard content
            if let previous = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
                print("Restored previous clipboard content")
            }
            throw ClipboardError.noTextSelected
        }
        
        print("Successfully captured text: \(selectedText.prefix(50))...")
        return selectedText
    }
    
    func replaceSelectedText(with newText: String) throws {
        print("Attempting to replace text with new content (length: \(newText.count))")
        
        // Store new text in clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        print("New text stored in clipboard")
        
        // Simulate paste command
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        print("Simulating CMD+V to paste improved text")
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the paste to complete
        Thread.sleep(forTimeInterval: 0.1)
        
        // Restore previous clipboard content
        if let previous = previousContent {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
            print("Restored previous clipboard content")
        }
        
        print("Text replacement complete")
    }
}
