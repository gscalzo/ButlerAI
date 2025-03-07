import Foundation

enum AIBackend {
    case openAI
    case ollama
}

struct OpenAIError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
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
                LoggerService.shared.log("Invalid response from Ollama server", type: .error)
                throw OpenAIError(message: "Invalid response from Ollama server")
            }
            
            if httpResponse.statusCode != 200 {
                LoggerService.shared.log("HTTP \(httpResponse.statusCode) from Ollama server", type: .error)
                throw OpenAIError(message: "HTTP \(httpResponse.statusCode) from Ollama server")
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
        } catch {
            LoggerService.shared.log("Failed to fetch Ollama models: \(error.localizedDescription)", type: .error)
            throw OpenAIError(message: "Failed to fetch Ollama models: \(error.localizedDescription)")
        }
    }
    
    init(apiKey: String, prompt: String, backend: AIBackend = .openAI, model: String = "gpt-4o-mini", serverURL: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.backend = backend
        self.model = model
        self.baseURL = URL(string: backend == .openAI ? serverURL : "\(serverURL)/v1")!
        // Add safety instruction and text delimiters to the prompt
        self.basePrompt = prompt
        LoggerService.shared.log("AIService initialized with backend: \(backend), model: \(model) (API Key present: \(!apiKey.isEmpty))")
    }
    
    func improveText(_ text: String) async throws -> String {
        LoggerService.shared.log("Starting text improvement request")
        guard !apiKey.isEmpty else {
            LoggerService.shared.log("Error: API key is empty", type: .error)
            throw OpenAIError(message: "OpenAI API key not configured")
        }
        
        // Using configured endpoint
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if backend == .openAI {
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
                LoggerService.shared.log("Error: Invalid response type from server", type: .error)
                throw OpenAIError(message: "Invalid response from server")
            }
            
            if httpResponse.statusCode != 200 {
                LoggerService.shared.log("HTTP Error: \(httpResponse.statusCode)", type: .error)
                if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    LoggerService.shared.log("AI Service Error: \(errorResponse.error.message)", type: .error)
                    throw OpenAIError(message: errorResponse.error.message)
                }
                throw OpenAIError(message: "HTTP \(httpResponse.statusCode)")
            }
            
            LoggerService.shared.log("Parsing AI service response")
            let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = apiResponse.choices.first?.message.content else {
                LoggerService.shared.log("Error: No content in response", type: .error)
                throw OpenAIError(message: "No content in response")
            }
            
            let finalContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            LoggerService.shared.log("Successfully extracted improved text (length: \(finalContent.count))")
            return finalContent
            
        } catch {
            LoggerService.shared.log("Error during OpenAI request: \(error.localizedDescription)", type: .error)
            throw error
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
