import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case ai
    case prompt
    case permissions

    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    @ObservedObject var permissions: AccessibilityPermissionService
    @Binding var selectedTab: SettingsTab

    var body: some View {
        TabView(selection: $selectedTab) {
            AISettingsTab(settings: settings)
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(SettingsTab.ai)

            PromptSettingsTab(settings: settings)
                .tabItem { Label("Prompt", systemImage: "text.quote") }
                .tag(SettingsTab.prompt)

            PermissionsSettingsTab(permissions: permissions)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
        }
        .frame(width: 480)
    }
}

// MARK: - AI

private struct AISettingsTab: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        Form {
            Section("Backend") {
                Picker("AI Backend", selection: $settings.aiBackend) {
                    ForEach(AIBackendType.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch settings.aiBackend {
            case .openAI:
                OpenAISettingsSection(settings: settings)
            case .ollama:
                OllamaSettingsSection(settings: settings)
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 380)
    }
}

private struct OpenAISettingsSection: View {
    @ObservedObject var settings: SettingsService
    @State private var useCustomModel: Bool

    private static let customModelTag = "__custom__"

    init(settings: SettingsService) {
        self.settings = settings
        _useCustomModel = State(initialValue: !OpenAIModelCatalog.isKnown(settings.openAIModel))
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: { useCustomModel ? Self.customModelTag : settings.openAIModel },
            set: { newValue in
                if newValue == Self.customModelTag {
                    useCustomModel = true
                } else {
                    useCustomModel = false
                    settings.openAIModel = newValue
                }
            }
        )
    }

    private var supportedReasoningEfforts: [OpenAIReasoningEffort] {
        OpenAIClient.supportedReasoningEfforts(model: settings.openAIModel)
    }

    var body: some View {
        Section("OpenAI") {
            SecureField("API Key", text: $settings.openaiKey, prompt: Text("sk-…"))
                .textFieldStyle(.roundedBorder)

            Picker("Model", selection: modelSelection) {
                ForEach(OpenAIModelCatalog.options) { option in
                    Text(option.displayName).tag(option.id)
                }
                Divider()
                Text("Custom…").tag(Self.customModelTag)
            }

            if useCustomModel {
                TextField("Model ID", text: $settings.openAIModel, prompt: Text("e.g. gpt-5.6-terra"))
                    .textFieldStyle(.roundedBorder)
            } else if let option = OpenAIModelCatalog.option(for: settings.openAIModel) {
                Text(option.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !supportedReasoningEfforts.isEmpty {
                Picker("Reasoning Effort", selection: $settings.openAIReasoningEffort) {
                    ForEach(supportedReasoningEfforts) { effort in
                        Text(effort.displayName).tag(effort)
                    }
                }
                Text("Lower effort is faster and cheaper; text polishing rarely needs more than Low.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Advanced") {
            TextField("Base URL", text: $settings.openAIBaseURL, prompt: Text(SettingsService.defaultOpenAIBaseURL))
                .textFieldStyle(.roundedBorder)
            Text("Point this at any OpenAI-compatible server. Leave as-is for OpenAI.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OllamaSettingsSection: View {
    @ObservedObject var settings: SettingsService
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var errorMessage = ""

    /// Models offered by the picker; a hand-typed model that the server did not list stays selectable.
    private var pickerModels: [String] {
        let current = settings.ollamaModel
        guard !current.isEmpty, !availableModels.contains(current) else { return availableModels }
        return [current] + availableModels
    }

    var body: some View {
        Section("Ollama") {
            TextField("Server URL", text: $settings.ollamaURL, prompt: Text(SettingsService.defaultOllamaURL))
                .textFieldStyle(.roundedBorder)

            if isLoadingModels {
                ProgressView("Loading models…")
                    .controlSize(.small)
            } else if availableModels.isEmpty {
                TextField("Model", text: $settings.ollamaModel, prompt: Text("e.g. llama3"))
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("Model", selection: $settings.ollamaModel) {
                    ForEach(pickerModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Refresh Models") {
                Task { await fetchModels() }
            }
            .disabled(isLoadingModels)
        }
        .task { await fetchModels() }
    }

    private func fetchModels() async {
        isLoadingModels = true
        errorMessage = ""
        defer { isLoadingModels = false }

        do {
            availableModels = try await OllamaClient.fetchModels(serverURL: settings.ollamaURL)
            if settings.ollamaModel.isEmpty, let first = availableModels.first {
                settings.ollamaModel = first
            }
        } catch {
            errorMessage = error.localizedDescription
            availableModels = []
        }
    }
}

// MARK: - Prompt

private struct PromptSettingsTab: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        Form {
            Section {
                TextEditor(text: $settings.improvementPrompt)
                    .font(.body)
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Improvement Prompt")
            } footer: {
                Text("Sent as the system prompt before the selected text.")
            }

            Section {
                Button("Reset to Default") {
                    settings.resetImprovementPrompt()
                }
                .disabled(settings.isUsingDefaultPrompt)
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 380)
    }
}

// MARK: - Permissions

private struct PermissionsSettingsTab: View {
    @ObservedObject var permissions: AccessibilityPermissionService

    var body: some View {
        Form {
            Section("Accessibility") {
                AccessibilityPermissionView(service: permissions)
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Improve Selected Text") {
                    Text(HotkeyManager.improveTextShortcut.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 380)
    }
}
