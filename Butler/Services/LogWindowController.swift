import SwiftUI
import AppKit

class LogWindowController: NSWindowController, NSWindowDelegate {
    var onClose: () -> Void = {}
    
    convenience init(onClose: @escaping () -> Void = {}) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "ButlerAI Logs"
        window.center()
        
        self.init(window: window)
        self.onClose = onClose
        window.delegate = self
        
        let hostingView = NSHostingView(rootView: LogView())
        window.contentView = hostingView
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
