import Foundation

/// Client for OpenAI's Chat Completions API. Also works with OpenAI-compatible servers via a custom base URL.
final class OpenAIClient: TextImproving {
    static let defaultBaseURL = URL(string: "https://api.openai.com/v1")!
    /// Output budget for legacy (non-reasoning) models: `max_tokens` covers visible output only.
    static let maxOutputTokens = 4096
    /// Budget for reasoning models: `max_completion_tokens` covers reasoning *and* visible output,
    /// so it needs headroom or the answer is cut off with `finish_reason: "length"`.
    static let maxReasoningCompletionTokens = 16_000
    static let legacyTemperature = 0.7

    private let apiKey: String
    private let basePrompt: String
    private let model: String
    private let baseURL: URL
    private let reasoningEffort: OpenAIReasoningEffort
    private let http: HTTPJSONClient

    init(
        apiKey: String,
        prompt: String,
        model: String = AIModelConstants.defaultOpenAIModel,
        serverURL: String,
        reasoningEffort: OpenAIReasoningEffort = .default,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.basePrompt = prompt
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = Self.resolveBaseURL(serverURL)
        self.reasoningEffort = reasoningEffort
        self.http = HTTPJSONClient(session: session)
        log("OpenAI client initialized with model: \(self.model) (API key present: \(!self.apiKey.isEmpty)), base URL: \(baseURL.absoluteString)")
    }

    // MARK: - URL handling

    /// Turns the user-provided server URL into a usable base URL. Accepts scheme-less input such as
    /// `localhost:1234/v1` and falls back to the official API when blank or malformed.
    static func resolveBaseURL(_ serverURL: String) -> URL {
        HTTPURLNormalizer.url(from: serverURL, defaultScheme: "https") ?? defaultBaseURL
    }

    /// `<base>/chat/completions` when the base already ends in `/v1`, otherwise `<base>/v1/chat/completions`.
    static func chatEndpoint(baseURL: URL) -> URL {
        var path = baseURL.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.hasSuffix("/v1") {
            return baseURL.appendingPathComponent("chat/completions")
        }
        return baseURL.appendingPathComponent("v1/chat/completions")
    }

    // MARK: - Model capabilities

    /// GPT-5-family and o-series models are reasoning models: they take `max_completion_tokens` and
    /// `reasoning_effort`, and reject sampling parameters such as `temperature` or `max_tokens`.
    static func usesReasoningParameters(model: String) -> Bool {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["gpt-5", "o1", "o3", "o4"].contains { normalized.hasPrefix($0) }
    }

    /// Reasoning effort values a model accepts. `none` only exists from GPT-5.1 onward, so it is offered
    /// for the curated GPT-5.6 catalog only; older reasoning models reject it with HTTP 400.
    static func supportedReasoningEfforts(model: String) -> [OpenAIReasoningEffort] {
        guard usesReasoningParameters(model: model) else { return [] }
        if OpenAIModelCatalog.isKnown(model) {
            return OpenAIReasoningEffort.allCases
        }
        return OpenAIReasoningEffort.allCases.filter { $0 != .none }
    }

    /// The effort actually sent: the requested one when the model supports it, otherwise the default.
    static func effectiveReasoningEffort(_ requested: OpenAIReasoningEffort, model: String) -> OpenAIReasoningEffort {
        supportedReasoningEfforts(model: model).contains(requested) ? requested : .default
    }

    // MARK: - Requests

    func makeRequestBody(for text: String) -> OpenAIChatRequest {
        var request = OpenAIChatRequest(
            model: model,
            messages: [.system(basePrompt), .user(text)]
        )
        if Self.usesReasoningParameters(model: model) {
            request.maxCompletionTokens = Self.maxReasoningCompletionTokens
            request.reasoningEffort = Self.effectiveReasoningEffort(reasoningEffort, model: model).rawValue
        } else {
            request.maxTokens = Self.maxOutputTokens
            request.temperature = Self.legacyTemperature
        }
        return request
    }

    func improveText(_ text: String) async throws -> String {
        log("Starting OpenAI text improvement request")
        guard !apiKey.isEmpty else {
            log("Error: API key is empty for OpenAI", type: .error)
            throw AIServiceError.missingApiKey
        }
        guard !model.isEmpty else {
            log("Error: no OpenAI model configured", type: .error)
            throw AIServiceError.missingModel
        }

        let endpoint = Self.chatEndpoint(baseURL: baseURL)
        log("Preparing OpenAI request for model \(model) with text length: \(text.count)")

        let response = try await http.post(
            endpoint,
            body: makeRequestBody(for: text),
            headers: ["Authorization": "Bearer \(apiKey)"],
            as: OpenAIResponse.self
        )

        let choice = response.choices.first
        if choice?.finishReason == "length" {
            // A cut-off rewrite must never be pasted over the user's text.
            log("Error: response truncated by the token budget (finish_reason=length)", type: .error)
            throw AIServiceError.responseTruncated
        }

        let message = choice?.message
        let content = message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            if let refusal = message?.refusal, !refusal.isEmpty {
                log("Model refused the request: \(refusal)", type: .warning)
            }
            log("Error: No content in response", type: .error)
            throw AIServiceError.noContentInResponse
        }

        log("Successfully extracted improved text (length: \(content.count))")
        return content
    }
}

// MARK: - Wire formats

/// Chat Completions request. Optional fields are omitted from the JSON when nil, so only the
/// parameters valid for the selected model are sent.
struct OpenAIChatRequest: Codable, Equatable {
    var model: String
    var messages: [ChatMessage]
    var maxCompletionTokens: Int?
    var reasoningEffort: String?
    var maxTokens: Int?
    var temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case reasoningEffort = "reasoning_effort"
        case maxTokens = "max_tokens"
        case temperature
    }
}

/// Chat Completions response. Everything but `choices` is optional because OpenAI-compatible
/// servers frequently omit metadata such as `id` or `usage`.
struct OpenAIResponse: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
        let index: Int?
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let role: String?
        /// `nil` when the model returns a `refusal` instead of content.
        let content: String?
        let refusal: String?
    }

    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
