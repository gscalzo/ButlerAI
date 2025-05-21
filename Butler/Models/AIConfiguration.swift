import Foundation

enum AIBackendType: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case ollama = "ollama"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .ollama: return "Ollama (Local)"
        }
    }
}

struct AIModelConstants {
    static let defaultOpenAIModel = "gpt-4o-mini"
}
