import Foundation

/// Client for a local Ollama server (`/api/chat`, `/api/tags`).
final class OllamaClient: TextImproving {
    static let defaultServerURL = "http://localhost:11434"
    static let temperature = 0.7

    private let basePrompt: String
    private let model: String
    private let baseURL: URL
    private let http: HTTPJSONClient

    init(prompt: String, model: String, serverURL: String, session: URLSession = .shared) {
        self.basePrompt = prompt
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = Self.resolveBaseURL(serverURL)
        self.http = HTTPJSONClient(session: session)
        log("Ollama client initialized with model: \(self.model), base URL: \(baseURL.absoluteString)")
    }

    // MARK: - URL handling

    /// Turns the user-provided server URL into a usable base URL. Accepts scheme-less input such as
    /// `myhost:11434` and falls back to localhost when blank or malformed.
    static func resolveBaseURL(_ serverURL: String) -> URL {
        HTTPURLNormalizer.url(from: serverURL, defaultScheme: "http") ?? URL(string: defaultServerURL)!
    }

    static func chatEndpoint(baseURL: URL) -> URL {
        baseURL.appendingPathComponent("api/chat")
    }

    static func modelsEndpoint(baseURL: URL) -> URL {
        baseURL.appendingPathComponent("api/tags")
    }

    // MARK: - Models

    static func fetchModels(serverURL: String = defaultServerURL, session: URLSession = .shared) async throws -> [String] {
        let baseURL = resolveBaseURL(serverURL)
        log("Fetching models from Ollama server: \(baseURL.absoluteString)")
        let response = try await HTTPJSONClient(session: session).get(
            modelsEndpoint(baseURL: baseURL),
            as: OllamaModelsResponse.self
        )
        log("Successfully fetched \(response.models.count) models from Ollama")
        return response.models.map(\.name)
    }

    // MARK: - Requests

    func makeRequestBody(for text: String) -> OllamaChatRequest {
        OllamaChatRequest(
            model: model,
            messages: [.system(basePrompt), .user(text)],
            stream: false,
            options: OllamaChatRequest.Options(temperature: Self.temperature)
        )
    }

    func improveText(_ text: String) async throws -> String {
        log("Starting Ollama text improvement request")
        guard !model.isEmpty else {
            log("Error: no Ollama model configured", type: .error)
            throw AIServiceError.missingModel
        }
        log("Preparing Ollama request for model \(model) with text length: \(text.count)")

        let response = try await http.post(
            Self.chatEndpoint(baseURL: baseURL),
            body: makeRequestBody(for: text),
            as: OllamaChatResponse.self
        )

        let content = response.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            log("Error: No content in Ollama response", type: .error)
            throw AIServiceError.noContentInResponse
        }

        log("Successfully extracted improved text (length: \(content.count))")
        return content
    }
}

// MARK: - Wire formats

struct OllamaChatRequest: Codable, Equatable {
    struct Options: Codable, Equatable {
        let temperature: Double
    }

    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let options: Options
}

struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let role: String?
        let content: String
    }

    let message: Message
}

struct OllamaModelsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}
