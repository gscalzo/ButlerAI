//
//  ContentView.swift
//  Butler
//
//  Created by Scalzo, Giordano on 04/03/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var apiKey: String = ""
    @State private var selectedBackend: AIBackend = .openAI
    @State private var ollamaServerURL: String = "http://localhost:11434"
    @State private var selectedModel: String = "gpt-4o-mini"
    @State private var availableModels: [String] = []
    @State private var isLoadingModels: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("AI Backend")) {
                Picker("Backend", selection: $selectedBackend) {
                    Text("OpenAI").tag(AIBackend.openAI)
                    Text("Ollama (Local)").tag(AIBackend.ollama)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedBackend) { _ in
                    if selectedBackend == .ollama {
                        Task {
                            await fetchOllamaModels()
                        }
                    } else {
                        selectedModel = "gpt-4o-mini"
                    }
                }
            }
            
            if selectedBackend == .openAI {
                Section(header: Text("OpenAI Configuration")) {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Model: gpt-4o-mini")
                        .foregroundColor(.secondary)
                }
            } else {
                Section(header: Text("Ollama Configuration")) {
                    TextField("Server URL", text: $ollamaServerURL)
                        .textFieldStyle(.roundedBorder)
                    
                    if isLoadingModels {
                        ProgressView("Loading models...")
                    } else {
                        Picker("Model", selection: $selectedModel) {
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
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
    }
    
    private func fetchOllamaModels() async {
        isLoadingModels = true
        errorMessage = ""
        
        do {
            availableModels = try await OpenAIService.fetchOllamaModels(serverURL: ollamaServerURL)
            if !availableModels.isEmpty {
                selectedModel = availableModels[0]
            }
        } catch {
            errorMessage = error.localizedDescription
            availableModels = []
        }
        
        isLoadingModels = false
    }
}

#Preview {
    ContentView()
}
