import Foundation

/// Anything that can rewrite a piece of text into an improved version.
///
/// Implementations wrap a concrete AI backend (OpenAI, Ollama, ...). Errors are surfaced as `AIServiceError`.
protocol TextImproving {
    /// Returns the improved version of `text`, trimmed of surrounding whitespace.
    func improveText(_ text: String) async throws -> String
}

/// A single chat turn as understood by every supported backend (`system`, `user`, `assistant`).
struct ChatMessage: Codable, Equatable {
    let role: String
    let content: String

    static func system(_ content: String) -> ChatMessage { ChatMessage(role: "system", content: content) }
    static func user(_ content: String) -> ChatMessage { ChatMessage(role: "user", content: content) }
}
