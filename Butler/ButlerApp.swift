import SwiftUI
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    let settingsService: SettingsService
    let accessibilityPermissions = AccessibilityPermissionService()

    @Published private(set) var isProcessing = false
    @Published var settingsTab: SettingsTab = .ai
    @Published var lastError: String? {
        didSet {
            if let error = lastError {
                log(error, type: .error)
            }
        }
    }

    /// Set by the menu so the app can open the SwiftUI Settings scene from outside a view.
    var openSettingsHandler: (() -> Void)?

    private var hotkeyManager: HotkeyManager?
    private let clipboardManager = ClipboardManager()
    private var languageService: LanguageService
    private var cancellables = Set<AnyCancellable>()

    init() {
        log("Initializing ButlerAI")
        let settings = SettingsService()
        self.settingsService = settings
        self.languageService = LanguageService(textImprover: Self.makeTextImprover(from: settings))

        if RuntimeEnvironment.isRunningTests {
            log("Skipping accessibility and hotkey setup during tests")
        } else {
            setupAccessibilityPermissions()
            setupHotkeyManager()
        }

        // Rebuild the AI client once the user stops typing rather than on every keystroke.
        settings.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAIService()
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    private static func makeTextImprover(from settings: SettingsService) -> TextImproving {
        switch settings.aiBackend {
        case .openAI:
            return OpenAIClient(
                apiKey: settings.openaiKey,
                prompt: settings.improvementPrompt,
                model: settings.openAIModel,
                serverURL: settings.openAIBaseURL,
                reasoningEffort: settings.openAIReasoningEffort
            )
        case .ollama:
            return OllamaClient(
                prompt: settings.improvementPrompt,
                model: settings.ollamaModel,
                serverURL: settings.ollamaURL
            )
        }
    }

    private func updateAIService() {
        languageService = LanguageService(textImprover: Self.makeTextImprover(from: settingsService))
        log("AI service updated (Backend: \(settingsService.aiBackend.rawValue), Model: \(settingsService.activeModel))")
    }

    private func setupAccessibilityPermissions() {
        if !accessibilityPermissions.isGranted {
            log("Accessibility access missing at launch; requesting it from macOS", type: .warning)
            accessibilityPermissions.requestAccess()
        }
        accessibilityPermissions.startMonitoring()
    }

    private func setupHotkeyManager() {
        log("Setting up hotkey (\(HotkeyManager.improveTextShortcut.displayString))")
        let manager = HotkeyManager(permissionService: accessibilityPermissions) { [weak self] in
            log("Hotkey triggered")
            Task { [weak self] in
                await self?.improveSelectedText()
            }
        }
        manager.start()
        hotkeyManager = manager
    }

    // MARK: - Actions

    func openSettings(tab: SettingsTab) {
        settingsTab = tab
        if let openSettingsHandler {
            openSettingsHandler()
        } else {
            log("Cannot open Settings: no handler registered yet", type: .error)
        }
    }

    private func improveSelectedText() async {
        guard !isProcessing else {
            log("Ignoring hotkey: an improvement is already in progress", type: .warning)
            return
        }

        log("Starting text improvement")
        isProcessing = true
        do {
            let selectedText = try await clipboardManager.getSelectedText()
            log("Selected text: \(selectedText.prefix(50))...")

            let improved = try await languageService.improveWithLanguageHandling(selectedText)
            log("Received improved text from AI service")

            try await clipboardManager.replaceSelectedText(with: improved)
            log("Successfully replaced text")
            lastError = nil
            isProcessing = false
        } catch {
            isProcessing = false
            // Never leave the user's clipboard holding the captured selection.
            clipboardManager.restorePreviousClipboard()
            present(error)
        }
    }

    private func present(_ error: Error) {
        switch error {
        case AIServiceError.missingApiKey:
            lastError = "OpenAI API key not configured."
            let openSettings = AlertPresenter.confirmOpenSettings(
                title: "OpenAI API Key Required",
                message: "Enter your OpenAI API key in Settings to use ButlerAI."
            )
            if openSettings { self.openSettings(tab: .ai) }

        case AIServiceError.missingModel:
            lastError = "No AI model configured."
            let openSettings = AlertPresenter.confirmOpenSettings(
                title: "AI Model Required",
                message: "Choose an AI model in Settings to use ButlerAI."
            )
            if openSettings { self.openSettings(tab: .ai) }

        case AIServiceError.networkError where settingsService.aiBackend == .ollama:
            lastError = "Ollama connection failed."
            let openSettings = AlertPresenter.confirmOpenSettings(
                title: "Ollama Connection Error",
                message: "Make sure Ollama is running and the server URL in Settings is correct."
            )
            if openSettings { self.openSettings(tab: .ai) }

        case let error as AIServiceError:
            log("AI service error: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            AlertPresenter.show(title: "\(settingsService.aiBackend.displayName) Error", message: error.localizedDescription)

        case ClipboardManager.ClipboardError.noTextSelected:
            lastError = error.localizedDescription
            AlertPresenter.show(
                title: "No Text Selected",
                message: "Select some text, then press \(HotkeyManager.improveTextShortcut.displayString)."
            )

        case let error as ClipboardManager.ClipboardError:
            log("Clipboard error: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            AlertPresenter.show(title: "Clipboard Error", message: error.localizedDescription)

        default:
            log("Unexpected error: \(error)", type: .error)
            lastError = "An unexpected error occurred"
        }
    }
}

@main
struct ButlerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            MenuBarLabel(appState: appState)
        }

        Settings {
            SettingsView(
                settings: appState.settingsService,
                permissions: appState.accessibilityPermissions,
                selectedTab: $appState.settingsTab
            )
        }

        Window("ButlerAI Logs", id: "logs") {
            LogView()
        }
        .defaultSize(width: 800, height: 600)
    }
}

/// The menu bar label. It is always rendered, which makes it the reliable place to capture the
/// `openSettings` environment action for use outside views (alerts triggered by the hotkey).
struct MenuBarLabel: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        StatusIcon(isProcessing: appState.isProcessing)
            .onAppear {
                appState.openSettingsHandler = { openSettings() }
            }
    }
}

/// Wand icon that turns into a spinning clock while a request is in flight.
struct StatusIcon: View {
    let isProcessing: Bool

    var body: some View {
        if isProcessing {
            Image(systemName: "clock.arrow.circlepath")
                .imageScale(.medium)
                .rotationEffect(.degrees(isProcessing ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
        } else {
            Image(systemName: "wand.and.stars")
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var settings: SettingsService
    @ObservedObject private var permissions: AccessibilityPermissionService
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    init(appState: AppState) {
        _appState = ObservedObject(wrappedValue: appState)
        _settings = ObservedObject(wrappedValue: appState.settingsService)
        _permissions = ObservedObject(wrappedValue: appState.accessibilityPermissions)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    StatusIcon(isProcessing: appState.isProcessing)
                        .frame(width: 18, height: 18)
                    Text("ButlerAI")
                        .font(.headline)
                }
                Text("\(settings.aiBackend.displayName) · \(settings.activeModel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Select text, then press \(HotkeyManager.improveTextShortcut.displayString)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)

            Divider()

            if !permissions.isGranted {
                AccessibilityStatusBanner(service: permissions) {
                    appState.openSettings(tab: .permissions)
                }

                Divider()
            }

            if let error = appState.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .lineLimit(3)
                    .padding(.vertical, 8)
                    .padding(.horizontal)

                Divider()
            }

            Button("Show Logs") {
                log("Opening logs from menu")
                openWindow(id: "logs")
            }
            .keyboardShortcut("l")
            .padding(.vertical, 4)

            Button("Settings...") {
                log("Opening settings from menu")
                openSettings()
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
        .onAppear {
            // Opening the menu is the natural moment to show the true permission state.
            permissions.refresh()
            appState.openSettingsHandler = { openSettings() }
        }
    }
}
