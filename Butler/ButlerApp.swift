import SwiftUI
import AppKit

@MainActor
class AppState: ObservableObject {
    private var hotkeyManager: HotkeyManager?
    private let clipboardManager = ClipboardManager()
    private var openAIService: OpenAIService?
    @Published var isSettingsOpen = false
    @Published var lastError: String?
    
    @AppStorage("openaiKey") var openaiKey: String = "" {
        didSet { updateOpenAIService() }
    }
    @AppStorage("improvementPrompt") var improvementPrompt: String = """
    Please improve the English in the following text while keeping its original meaning and tone. Focus on grammar, clarity, and natural expression. Return only the improved text without any explanations or additional comments.
    """ {
        didSet { updateOpenAIService() }
    }
    
    init() {
        updateOpenAIService()
        setupHotkeyManager()
    }
    
    private func updateOpenAIService() {
        openAIService = OpenAIService(apiKey: openaiKey, prompt: improvementPrompt)
    }
    
    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager { [weak self] in
            Task { [weak self] in
                await self?.improveSelectedText()
            }
        }
    }
    
    private func improveSelectedText() async {
        do {
            let selectedText = try clipboardManager.getSelectedText()
            guard let improved = try await openAIService?.improveText(selectedText) else {
                lastError = "OpenAI service not configured"
                return
            }
            try clipboardManager.replaceSelectedText(with: improved)
            lastError = nil
        } catch let error as OpenAIError {
            lastError = error.localizedDescription
        } catch let error as ClipboardManager.ClipboardError {
            lastError = error.localizedDescription
        } catch {
            lastError = "An unexpected error occurred"
        }
    }
}

@main
struct ButlerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("Butler", systemImage: "pencil") {
            Button("Settings") {
                appState.isSettingsOpen = true
            }
            .keyboardShortcut(",")
            
            Divider()
            
            if let error = appState.lastError {
                Text(error)
                    .foregroundColor(.red)
                Divider()
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView(appState: appState)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        Form {
            Section(header: Text("OpenAI Configuration")) {
                SecureField("API Key", text: $appState.openaiKey)
                    .textFieldStyle(.roundedBorder)
                
                Text("Improvement Prompt")
                TextEditor(text: $appState.improvementPrompt)
                    .frame(height: 100)
                    .border(.secondary)
            }
            .padding()
            
            Section(header: Text("Keyboard Shortcut")) {
                Text("⌃⌥⌘C - Improve Selected Text")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 400)
    }
}
