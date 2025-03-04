import Foundation

struct OpenAIError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}

class OpenAIService {
    private let apiKey: String
    private let prompt: String
    
    init(apiKey: String, prompt: String) {
        self.apiKey = apiKey
        self.prompt = prompt
    }
    
    func improveText(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError(message: "OpenAI API key not configured")
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError(message: "Invalid response from server")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw OpenAIError(message: error.error.message)
            }
            throw OpenAIError(message: "HTTP \(httpResponse.statusCode)")
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let improvedText = message["content"] as? String {
            return improvedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw OpenAIError(message: "Failed to parse OpenAI response")
    }
}

struct OpenAIErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
    }
    let error: ErrorDetail
}
