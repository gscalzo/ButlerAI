import Foundation
import NaturalLanguage
import SwiftUI

class LanguageService: ObservableObject {
    private let openAIService: OpenAIService
    
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
    }
    
    func detectLanguage(text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage?.rawValue,
              language == "it" else { return nil }
        return language
    }
    
    func translateAndImprove(italianText: String) async throws -> String {
        let prompt = """
        Translate this Italian text to English and improve its clarity and fluency while maintaining the original meaning:
        
        \(italianText)
        """
        
        return try await openAIService.improveText(prompt)
    }
    
    func improveWithLanguageHandling(_ text: String) async throws -> String {
        // Check for Italian first (preserving current behavior)
        if detectLanguage(text: text) == "it" {
            // Use existing translation + improvement
            return try await translateAndImprove(italianText: text)
        } else {
            // Use existing improvement directly
            return try await openAIService.improveText(text)
        }
    }
}
