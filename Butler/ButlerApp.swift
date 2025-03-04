import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: () -> Void = {}
    
    func windowWillClose(_ notification: Notification) {
        print("Settings window closed")
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
            print("Settings window state: \(self.isSettingsOpen)")
            if self.isSettingsOpen {
                self.showSettings()
            }
        }
    }
    @Published var lastError: String? {
        didSet {
            if let error = self.lastError {
                print("Error: \(error)")
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
        print("Initializing ButlerAI")
        self.updateOpenAIService()
        self.setupHotkeyManager()
    }
    
    private func updateOpenAIService() {
        openAIService = OpenAIService(apiKey: openaiKey, prompt: improvementPrompt)
        print("OpenAI service updated (API Key length: \(openaiKey.count))")
    }
    
    private func setupHotkeyManager() {
        print("Setting up hotkey (⌃⌥⌘C)")
        hotkeyManager = HotkeyManager { [weak self] in
            print("Hotkey triggered")
            Task { [weak self] in
                await self?.improveSelectedText()
            }
        }
    }
    
    private func showSettings() {
        print("Showing settings window")
        
        if let controller = settingsWindowController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("Reusing existing settings window")
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "ButlerAI Settings"
        window.center()
        
        let controller = SettingsWindowController(window: window)
        controller.onClose = { [weak self] in
            print("Settings window will be cleaned up")
            self?.settingsWindowController = nil
            self?.isSettingsOpen = false
        }
        window.delegate = controller
        
        let hostingView = NSHostingView(rootView: SettingsView(appState: self))
        window.contentView = hostingView
        
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("New settings window created and shown")
    }
    
    private func improveSelectedText() async {
        print("Starting text improvement")
        do {
            let selectedText = try clipboardManager.getSelectedText()
            print("Selected text: \(selectedText.prefix(50))...")
            
            guard let improved = try await openAIService?.improveText(selectedText) else {
                lastError = "OpenAI API key not configured"
                let alert = NSAlert()
                alert.messageText = "OpenAI API Key Required"
                alert.informativeText = "Please open Settings and enter your OpenAI API key to use ButlerAI."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    self.isSettingsOpen = true
                }
                return
            }
            print("Received improved text from OpenAI")
            
            try clipboardManager.replaceSelectedText(with: improved)
            print("Successfully replaced text")
            lastError = nil
        } catch let error as OpenAIError {
            print("OpenAI error: \(error.localizedDescription)")
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "OpenAI Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch let error as ClipboardManager.ClipboardError {
            print("Clipboard error: \(error.localizedDescription)")
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "No Text Selected"
            alert.informativeText = "Please select some text to improve."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch {
            print("Unexpected error: \(error)")
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
                    Text("ButlerAI")
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
                    print("Opening settings from menu")
                    appState.isSettingsOpen = true
                }
                .keyboardShortcut(",")
                .padding(.vertical, 4)
                
                Button("Quit ButlerAI") {
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
