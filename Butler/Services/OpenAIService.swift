import Foundation

// AIBackend enum was here, now removed. AIBackendType from AIConfiguration.swift is used.

enum OpenAIError: LocalizedError {
    case missingApiKey
    case networkError(underlyingError: Error)
    case invalidResponse(statusCode: Int, responseBody: String?)
    case responseDecodingError(underlyingError: Error)
    case noContentInResponse
    case serviceError(message: String) // For errors reported by the AI service itself
    case unknownError(message: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "The API key is missing or not configured."
        case .networkError(let underlyingError):
            return "A network error occurred: \(underlyingError.localizedDescription)"
        case .invalidResponse(let statusCode, let responseBody):
            var bodyHint = ""
            if let body = responseBody, !body.isEmpty {
                bodyHint = " Body: \(body.prefix(100))..."
            }
            return "Received an invalid response from the server (HTTP \(statusCode)).\(bodyHint)"
        case .responseDecodingError(let underlyingError):
            return "Failed to decode the server's response: \(underlyingError.localizedDescription)"
        case .noContentInResponse:
            return "The server's response did not contain any content."
        case .serviceError(let message):
            return message // This is the message directly from the AI service's error response
        case .unknownError(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}

class OpenAIService {
    private let apiKey: String
    private let basePrompt: String
    private let backend: AIBackend
    private let model: String
    private let baseURL: URL
    
    static func fetchOllamaModels(serverURL: String = "http://localhost:11434") async throws -> [String] {
        let url = URL(string: "\(serverURL)/api/tags")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        LoggerService.shared.log("Fetching models from Ollama server: \(serverURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                LoggerService.shared.log("Invalid response from Ollama server (not an HTTPURLResponse)", type: .error)
                throw OpenAIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, responseBody: "Response was not HTTPURLResponse")
            }
            
            if httpResponse.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8)
                LoggerService.shared.log("HTTP \(httpResponse.statusCode) from Ollama server. Body: \(responseBody ?? "nil")", type: .error)
                throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
            }
            
            // Parse Ollama response
            struct OllamaModelsResponse: Codable {
                struct Model: Codable {
                    let name: String
                }
                let models: [Model]
            }
            
            let modelResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            LoggerService.shared.log("Successfully fetched \(modelResponse.models.count) models from Ollama")
            return modelResponse.models.map { $0.name }
        } catch let error as DecodingError {
            LoggerService.shared.log("Failed to decode Ollama models response: \(error.localizedDescription)", type: .error)
            throw OpenAIError.responseDecodingError(underlyingError: error)
        } catch let error as OpenAIError {
            throw error // Re-throw OpenAIError explicitly if it was already one
        } catch {
            LoggerService.shared.log("Failed to fetch Ollama models: \(error.localizedDescription)", type: .error)
            throw OpenAIError.networkError(underlyingError: error)
        }
    }
    
    init(apiKey: String, prompt: String, backend: AIBackendType = .openAI, model: String = AIModelConstants.defaultOpenAIModel, serverURL: String) {
        self.apiKey = apiKey
        self.backend = backend
        self.model = model
        
        var effectiveBaseURL: String
        switch backend {
        case .openAI:
            if serverURL.isEmpty || serverURL == "https://api.openai.com/v1" {
                effectiveBaseURL = "https://api.openai.com/v1" 
            } else {
                // Assuming custom OpenAI-compatible endpoint
                effectiveBaseURL = serverURL 
            }
        case .ollama:
            // Ollama typically uses /api at the root of its server URL for specific actions
            // The actual path like /chat or /tags is appended later or in specific methods.
            effectiveBaseURL = serverURL 
        }
        // Ensure baseURL is just the server root for ollama, path will be appended in methods.
        // For OpenAI, it can include /v1 if standard, or be the root of a compatible API.
        self.baseURL = URL(string: effectiveBaseURL)!
        
        self.basePrompt = prompt
        LoggerService.shared.log("AIService initialized with backend: \(backend.rawValue), model: \(model) (API Key present: \(!apiKey.isEmpty)), BaseURL: \(self.baseURL.absoluteString)")
    }
    
    func improveText(_ text: String) async throws -> String {
        LoggerService.shared.log("Starting text improvement request")
        
        var effectiveURL: URL
        switch backend {
        case .openAI:
            // OpenAI chat completions are typically at /v1/chat/completions
            // If baseURL is "https://api.openai.com/v1", then append "chat/completions"
            // If baseURL is a custom one like "http://localhost:1234/v1", also append "chat/completions"
            // If baseURL is just "http://localhost:1234", assume it's a proxy that needs "/v1/chat/completions"
            if baseURL.absoluteString.hasSuffix("/v1") {
                 effectiveURL = baseURL.appendingPathComponent("chat/completions")
            } else if baseURL.absoluteString == "https://api.openai.com" { // Default base without /v1
                 effectiveURL = baseURL.appendingPathComponent("v1/chat/completions")
            } else { // Custom URL, assume it might be a proxy that needs the full path
                 effectiveURL = baseURL.appendingPathComponent("v1/chat/completions")
            }
        case .ollama:
            effectiveURL = baseURL.appendingPathComponent("api/chat")
        }
        
        var request = URLRequest(url: effectiveURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if backend == .openAI {
             guard !apiKey.isEmpty else {
                LoggerService.shared.log("Error: API key is empty for OpenAI", type: .error)
                throw OpenAIError.missingApiKey
            }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        LoggerService.shared.log("Preparing AI request for model \(model) with text length: \(text.count)")
        
        // Following official API structure
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": basePrompt
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 4096,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            LoggerService.shared.log("Request payload prepared")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            LoggerService.shared.log("Received response from AI service")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                LoggerService.shared.log("Error: Invalid response type from server (not HTTPURLResponse)", type: .error)
                throw OpenAIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, responseBody: "Response was not HTTPURLResponse")
            }
            
            if httpResponse.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8)
                LoggerService.shared.log("HTTP Error: \(httpResponse.statusCode). Body: \(responseBody ?? "nil")", type: .error)
                if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    LoggerService.shared.log("AI Service Error: \(errorResponse.error.message)", type: .error)
                    throw OpenAIError.serviceError(message: errorResponse.error.message)
                }
                throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
            }
            
            LoggerService.shared.log("Parsing AI service response")
            let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = apiResponse.choices.first?.message.content else {
                LoggerService.shared.log("Error: No content in response", type: .error)
                throw OpenAIError.noContentInResponse
            }
            
            let finalContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            LoggerService.shared.log("Successfully extracted improved text (length: \(finalContent.count))")
            return finalContent
            
        } catch let error as DecodingError {
            LoggerService.shared.log("Error decoding OpenAI response: \(error.localizedDescription)", type: .error)
            throw OpenAIError.responseDecodingError(underlyingError: error)
        } catch let error as OpenAIError {
            throw error // Re-throw OpenAIError explicitly
        } catch {
            LoggerService.shared.log("Error during OpenAI request: \(error.localizedDescription)", type: .error)
            throw OpenAIError.networkError(underlyingError: error)
        }
    }
}

// Response structures following OpenAI API
struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct OpenAIErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
    let error: ErrorDetail
}
