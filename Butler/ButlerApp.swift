import SwiftUI
import AppKit
import OSLog

let logger = Logger(subsystem: "com.butler.app", category: "main")

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: () -> Void = {}
    
    func windowWillClose(_ notification: Notification) {
        logger.info("Settings window will close")
        onClose()
    }
}

@MainActor
class AppState: ObservableObject {
    private var hotkeyManager: HotkeyManager?
    private let clipboardManager = ClipboardManager()
    private var openAIService: OpenAIService?
    private var settingsWindowController: SettingsWindowController?
    
    @Published var isSettingsOpen = false {
        didSet {
            logger.info("Settings window state changed: \(self.isSettingsOpen)")
            if self.isSettingsOpen {
                self.showSettings()
            }
        }
    }
    @Published var lastError: String? {
        didSet {
            if let error = self.lastError {
                logger.error("Error occurred: \(error)")
            }
        }
    }
    
    @AppStorage("openaiKey") var openaiKey: String = "" {
        didSet { self.updateOpenAIService() }
    }
    @AppStorage("improvementPrompt") var improvementPrompt: String = """
    Please improve the English in the following text while keeping its original meaning and tone. Focus on grammar, clarity, and natural expression. Return only the improved text without any explanations or additional comments.
    """ {
        didSet { self.updateOpenAIService() }
    }
    
    init() {
        logger.info("Initializing AppState")
        self.updateOpenAIService()
        self.setupHotkeyManager()
    }
    
    private func updateOpenAIService() {
        openAIService = OpenAIService(apiKey: openaiKey, prompt: improvementPrompt)
        logger.info("OpenAI service updated")
    }
    
    private func setupHotkeyManager() {
        logger.info("Setting up hotkey manager")
        hotkeyManager = HotkeyManager { [weak self] in
            logger.info("Hotkey triggered")
            Task { [weak self] in
                await self?.improveSelectedText()
            }
        }
    }
    
    private func showSettings() {
        logger.info("Showing settings window")
        
        if let controller = settingsWindowController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Butler Settings"
        window.center()
        
        let controller = SettingsWindowController(window: window)
        controller.onClose = { [weak self] in
            self?.settingsWindowController = nil
            self?.isSettingsOpen = false
        }
        window.delegate = controller
        
        let hostingView = NSHostingView(rootView: SettingsView(appState: self))
        window.contentView = hostingView
        
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        logger.info("Settings window created and shown")
    }
    
    private func improveSelectedText() async {
        logger.info("Attempting to improve selected text")
        do {
            let selectedText = try clipboardManager.getSelectedText()
            logger.info("Got selected text: \(selectedText.prefix(20))...")
            
            guard let improved = try await openAIService?.improveText(selectedText) else {
                lastError = "OpenAI API key not configured"
                let alert = NSAlert()
                alert.messageText = "OpenAI API Key Required"
                alert.informativeText = "Please open Settings and enter your OpenAI API key to use Butler."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    self.isSettingsOpen = true
                }
                return
            }
            logger.info("Received improved text from OpenAI")
            
            try clipboardManager.replaceSelectedText(with: improved)
            logger.info("Successfully replaced text")
            lastError = nil
        } catch let error as OpenAIError {
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "OpenAI Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch let error as ClipboardManager.ClipboardError {
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "No Text Selected"
            alert.informativeText = "Please select some text to improve."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch {
            lastError = "An unexpected error occurred"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI API Key")
                            .font(.headline)
                        SecureField("Enter your API key", text: $appState.openaiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Improvement Prompt")
                            .font(.headline)
                        TextEditor(text: $appState.improvementPrompt)
                            .font(.body)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text("⌃⌥⌘C")
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        Text("- Improve Selected Text")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(width: 400)
    }
}

@main
struct ButlerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Butler")
                        .font(.headline)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                if let error = appState.lastError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .lineLimit(3)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    
                    Divider()
                }
                
                Button("Settings...") {
                    appState.isSettingsOpen = true
                }
                .keyboardShortcut(",")
                .padding(.vertical, 4)
                
                Button("Quit Butler") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .padding(.vertical, 4)
            }
            .fixedSize()
        } label: {
            Image(systemName: "wand.and.stars")
        }
    }
}
