# Codebase Summary

## Project Structure
- `ButlerApp.swift`: Main application entry point
- `ContentView.swift`: Main view (minimal for menubar app)
- Supporting Files:
  - Assets.xcassets
  - Info.plist
  - Butler.entitlements

## Main Components
1. MenuBarManager
   - Handles menubar icon and menu
   - Manages app visibility

2. HotkeyManager
   - Registers and handles global shortcuts
   - Manages keyboard event monitoring

3. ClipboardManager
   - Handles text selection access
   - Manages clipboard operations

4. OpenAIService
   - Handles API communication with OpenAI and Ollama
   - Manages model selection and backend switching
   - Fetches available models from Ollama
   - Processes text improvements through chosen backend

5. ErrorHandler
   - Manages error popups
   - Provides user feedback

## Data Flow
1. User triggers keyboard shortcut
2. System captures selected text
3. Text sent to OpenAI
4. Response processed
5. Original text replaced

## Recent Changes
- Implemented complete menubar app functionality
- Added dual backend support (OpenAI and Ollama)
- Implemented model selection for Ollama backend
- Created unified settings UI for both backends
- Added dynamic model list fetching from Ollama
- Updated error handling for both backends
- Enhanced settings UI with backend switching

## Implementation Details

### AppState
The central state manager that:
- Coordinates between all services
- Manages settings persistence
- Handles error reporting
- Controls UI state

### Services
1. OpenAIService
   - Supports both OpenAI and Ollama backends
   - Manages backend selection and configuration
   - Handles model listing and selection for Ollama
   - Provides unified error handling for both APIs

2. ClipboardManager
   - Manages text selection capture
   - Handles text replacement
   - Preserves clipboard state

3. HotkeyManager
   - Registers global keyboard shortcut
   - Uses Carbon API for system-wide hotkey support
   - Manages keyboard event handling

### Settings
Persistent storage for:
- Selected AI backend (OpenAI/Ollama)
- OpenAI API key (secure storage)
- Ollama server URL
- Selected AI model
- Custom improvement prompt
- Error state

### Error Handling
Comprehensive error handling for:
- Backend-specific errors:
  - OpenAI: Missing API key, API limits
  - Ollama: Connection issues, model loading
- No text selected
- API communication issues
- Text replacement failures
- Model availability and selection
