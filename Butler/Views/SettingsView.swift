import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    @State private var availableModels: [String] = []
    @State private var isLoadingModels: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("AI Backend", selection: $settings.aiBackend) {
                        ForEach(AIBackendType.allCases) { backendType in
                            Text(backendType.displayName).tag(backendType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.aiBackend) { newValue in
                        if newValue == .ollama {
                            Task {
                                await fetchOllamaModels()
                            }
                        } else {
                            // Reset to default OpenAI model when switching back
                            settings.selectedModel = AIModelConstants.defaultOpenAIModel
                        }
                    }

                    if settings.aiBackend == .openAI {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API Key")
                                .font(.headline)
                            SecureField("Enter your API key", text: $settings.openaiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ollama Server URL")
                                .font(.headline)
                            TextField("Server URL", text: $settings.ollamaURL)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Model")
                                .font(.headline)
                            if isLoadingModels {
                                ProgressView("Loading models...")
                            } else {
                                Picker("Model", selection: $settings.selectedModel) {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .disabled(availableModels.isEmpty)
                                
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                Button("Refresh Models") {
                                    Task {
                                        await fetchOllamaModels()
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Improvement Prompt")
                            .font(.headline)
                        TextEditor(text: $settings.improvementPrompt)
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
    
    private func fetchOllamaModels() async {
        isLoadingModels = true
        errorMessage = ""
        
        do {
            availableModels = try await OpenAIService.fetchOllamaModels(serverURL: settings.ollamaURL)
            if !availableModels.isEmpty && !availableModels.contains(settings.selectedModel) {
                settings.selectedModel = availableModels[0]
            }
        } catch {
            errorMessage = error.localizedDescription
            availableModels = []
        }
        
        isLoadingModels = false
    }
}
