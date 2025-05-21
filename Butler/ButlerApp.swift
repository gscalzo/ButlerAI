import SwiftUI
import AppKit
import Combine

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: () -> Void = {}
    
    func windowWillClose(_ notification: Notification) {
        LoggerService.shared.log("Settings window closed")
        onClose()
    }
}

@MainActor
class AppState: ObservableObject {
    private var hotkeyManager: HotkeyManager?
    private let clipboardManager = ClipboardManager()
    private var openAIService: OpenAIService?
    private var languageService: LanguageService?
    private var settingsWindowController: SettingsWindowController?
    private var logWindowController: LogWindowController?
    @Published var isProcessing: Bool = false
    
    let settingsService = SettingsService()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isSettingsOpen = false {
        didSet {
            LoggerService.shared.log("Settings window state: \(self.isSettingsOpen)")
            if self.isSettingsOpen {
                self.showSettings()
            }
        }
    }
    @Published var lastError: String? {
        didSet {
            if let error = self.lastError {
                LoggerService.shared.log(error, type: .error)
            }
        }
    }
    
    init() {
        LoggerService.shared.log("Initializing ButlerAI")
        self.updateAIService() // Initial call
        self.setupHotkeyManager()
        
        settingsService.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    LoggerService.shared.log("SettingsService changed, updating AI Service.")
                    self?.updateAIService()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateAIService() {
        let serverURLForService: String
        switch settingsService.aiBackend {
        case .openAI:
            // Pass "" to OpenAIService, which will then default to "https://api.openai.com/v1" or handle custom OpenAI URL if ollamaURL is set to it.
            // For clarity, if ollamaURL is a valid URL and backend is OpenAI, it's treated as a custom OpenAI endpoint.
            // This depends on how settings are managed. Assuming ollamaURL is for Ollama, pass empty for OpenAI default.
            // Let's assume for now that if `settingsService.ollamaURL` is not the default "http://localhost:11434" AND `settingsService.aiBackend == .openAI`
            // then `settingsService.ollamaURL` is meant to be a custom OpenAI endpoint. Otherwise, for OpenAI, we pass an empty string.
            // This is a bit convoluted. A dedicated setting for OpenAI base URL would be cleaner.
            // Given current structure: OpenAIService expects a non-empty serverURL for Ollama.
            // For OpenAI, OpenAIService can take an empty string to mean "use default public OpenAI URL"
            // or a specific URL (like a proxy).
            // If settingsService.ollamaURL contains the default ollama URL, and the backend is OpenAI, we should probably send an empty string.
            // Otherwise, if it's OpenAI and ollamaURL is something else, that 'something else' is the intended custom OpenAI URL.
            if settingsService.ollamaURL != "http://localhost:11434" && !settingsService.ollamaURL.isEmpty { // Check if ollamaURL is custom
                 serverURLForService = settingsService.ollamaURL // Use as custom OpenAI endpoint if set
            } else {
                 serverURLForService = "" // Default to public OpenAI
            }
        case .ollama:
            serverURLForService = settingsService.ollamaURL
        }

        openAIService = OpenAIService(
            apiKey: settingsService.openaiKey,
            prompt: settingsService.improvementPrompt,
            backend: settingsService.aiBackend, // This is now AIBackendType
            model: settingsService.selectedModel,
            serverURL: serverURLForService 
        )
        if let openAIService = openAIService {
            languageService = LanguageService(openAIService: openAIService)
        }
        LoggerService.shared.log("AI service updated (Backend: \(settingsService.aiBackend.rawValue), Model: \(settingsService.selectedModel))")
    }
    
    private func setupHotkeyManager() {
        LoggerService.shared.log("Setting up hotkey (⌃⌥⌘C)")
        hotkeyManager = HotkeyManager { [weak self] in
            LoggerService.shared.log("Hotkey triggered")
            Task { [weak self] in
                await self?.improveSelectedText()
            }
        }
    }
    
    private func showSettings() {
        LoggerService.shared.log("Showing settings window")
        
        if let controller = settingsWindowController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            LoggerService.shared.log("Reusing existing settings window")
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
            LoggerService.shared.log("Settings window will be cleaned up")
            self?.settingsWindowController = nil
            self?.isSettingsOpen = false
        }
        window.delegate = controller
        
        let hostingView = NSHostingView(rootView: SettingsView(settings: self.settingsService))
        window.contentView = hostingView
        
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        LoggerService.shared.log("New settings window created and shown")
    }
    
    func showLogs() {
        LoggerService.shared.log("Showing logs window")
        
        if let controller = logWindowController {
            controller.showWindow()
            LoggerService.shared.log("Reusing existing logs window")
            return
        }
        
        logWindowController = LogWindowController { [weak self] in
            LoggerService.shared.log("Logs window will be cleaned up")
            self?.logWindowController = nil
        }
        
        logWindowController?.showWindow()
        LoggerService.shared.log("New logs window created and shown")
    }
    
    private func improveSelectedText() async {
        LoggerService.shared.log("Starting text improvement")
        do {
            isProcessing = true
            let selectedText = try clipboardManager.getSelectedText()
            LoggerService.shared.log("Selected text: \(selectedText.prefix(50))...")
            
            guard let improved = try await languageService?.improveWithLanguageHandling(selectedText) else {
                let errorMessage = settingsService.aiBackend == .openAI ?
                    "OpenAI API key not configured." :
                    "Ollama connection failed. Ensure Ollama is running and the URL is correct in settings."
                lastError = errorMessage
                let alert = NSAlert()
                alert.messageText = settingsService.aiBackend == .openAI ?
                    "OpenAI API Key Required" :
                    "Ollama Connection Error"
                alert.informativeText = settingsService.aiBackend == .openAI ?
                    "Please open Settings and enter your OpenAI API key to use ButlerAI." :
                    "Please make sure Ollama is running and check your server URL in Settings."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    self.isSettingsOpen = true
                }
                isProcessing = false
                return
            }
            LoggerService.shared.log("Received improved text from AI service")
            
            try clipboardManager.replaceSelectedText(with: improved)
            LoggerService.shared.log("Successfully replaced text")
            lastError = nil
            isProcessing = false
        } catch let error as OpenAIError {
            isProcessing = false
            LoggerService.shared.log("AI service error: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "\(settingsService.aiBackend.displayName) Error" // Using displayName from enum
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch let error as ClipboardManager.ClipboardError {
            isProcessing = false
            LoggerService.shared.log("Clipboard error: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "No Text Selected"
            alert.informativeText = "Please select some text to improve."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch {
            LoggerService.shared.log("Unexpected error: \(error)", type: .error)
            lastError = "An unexpected error occurred"
            isProcessing = false
        }
    }
}

@main
struct ButlerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Group {
                        if appState.isProcessing {
                            Image(systemName: "clock.arrow.circlepath")
                                .imageScale(.medium)
                                .rotationEffect(.degrees(appState.isProcessing ? 360 : 0))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: appState.isProcessing)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                    }
                    .frame(width: 18, height: 18)
                    
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
                
                Button("Show Logs") {
                    LoggerService.shared.log("Opening logs from menu")
                    appState.showLogs()
                }
                .keyboardShortcut("l")
                .padding(.vertical, 4)
                
                Button("Settings...") {
                    LoggerService.shared.log("Opening settings from menu")
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
            if appState.isProcessing {
                Image(systemName: "clock.arrow.circlepath")
                    .imageScale(.medium)
                    .rotationEffect(.degrees(appState.isProcessing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: appState.isProcessing)
            } else {
                Image(systemName: "wand.and.stars")
            }
        }
    }
}
