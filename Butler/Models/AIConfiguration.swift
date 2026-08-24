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

enum AIModelConstants {
    /// Default OpenAI model: GPT-5.6 Luna, the fastest and most cost-efficient tier of the GPT-5.6 family.
    static let defaultOpenAIModel = "gpt-5.6-luna"

    /// Models that shipped as the default in earlier releases. Used for a one-time settings migration
    /// so users who never picked a model explicitly are moved to the current default.
    static let previousDefaultOpenAIModels: [String] = ["gpt-4o-mini"]
}

/// A curated OpenAI model the user can pick from the settings UI.
struct OpenAIModelOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let summary: String
}

/// The OpenAI models surfaced in the settings picker. Any other model ID can still be entered manually.
enum OpenAIModelCatalog {
    static let options: [OpenAIModelOption] = [
        OpenAIModelOption(
            id: "gpt-5.6-luna",
            displayName: "GPT-5.6 Luna",
            summary: "Fastest and most cost-efficient — recommended"
        ),
        OpenAIModelOption(
            id: "gpt-5.6-terra",
            displayName: "GPT-5.6 Terra",
            summary: "Balances intelligence with cost"
        ),
        OpenAIModelOption(
            id: "gpt-5.6-sol",
            displayName: "GPT-5.6 Sol",
            summary: "Frontier model for complex work"
        )
    ]

    static func isKnown(_ id: String) -> Bool {
        option(for: id) != nil
    }

    static func option(for id: String) -> OpenAIModelOption? {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return options.first { $0.id == normalized }
    }
}

/// How much reasoning a GPT-5-family model spends before answering.
/// Lower effort is faster and cheaper; text polishing rarely needs more than `.low`.
enum OpenAIReasoningEffort: String, CaseIterable, Identifiable {
    case none
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    static let `default` = OpenAIReasoningEffort.low
}
