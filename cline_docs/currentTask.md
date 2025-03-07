# Current Task: Language Support Enhancement

## Completed Objectives
1. Added support for improving non-Italian text
2. Preserved existing Italian-to-English translation
3. Maintained compatibility with both OpenAI and Ollama backends
4. Integrated language detection in the main app flow

## Changes Made
1. Modified LanguageService.swift:
   - Added new `improveWithLanguageHandling` function
   - Preserved existing language detection logic
   - Maintained existing translation functionality
   - Added direct text improvement for non-Italian text

2. Modified ButlerApp.swift:
   - Added LanguageService property to AppState
   - Initialized LanguageService in updateAIService
   - Updated improveSelectedText to use LanguageService
   - Maintained existing error handling

3. Implementation Details:
   - Language detection remains focused on Italian
   - Italian text: translates to English then improves
   - Non-Italian text: directly improves using configured backend
   - Uses existing OpenAI/Ollama infrastructure

## Testing Completed
- Italian detection and translation (preserved)
- Non-Italian text improvement (new)
- Backend compatibility (OpenAI/Ollama)
- Error handling validation
- Service initialization and update flow

## Next Steps
1. Potential Improvements:
   - Add support for additional languages
   - Implement language-specific improvement prompts
   - Add language detection indicators
   - Consider automatic language detection toggle

2. Future Considerations:
   - Multi-language translation support
   - Language-specific model selection
   - Custom prompts per language
   - Language preference settings
