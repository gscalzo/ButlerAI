import Foundation

/// Errors surfaced by the AI backends (OpenAI, Ollama) and the shared HTTP transport.
enum AIServiceError: LocalizedError {
    case missingApiKey
    case missingModel
    case responseTruncated
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
        case .missingModel:
            return "No AI model is configured. Choose a model in Settings."
        case .responseTruncated:
            return "The model ran out of output tokens before finishing. Try selecting less text or lowering the reasoning effort in Settings."
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

/// OpenAI-style error envelope: `{"error": {"message": "...", ...}}`.
/// Many OpenAI-compatible servers use the same shape.
struct OpenAIErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
    let error: ErrorDetail
}

/// Ollama-style error envelope: `{"error": "model 'x' not found"}`.
struct OllamaErrorResponse: Decodable {
    let error: String
}
