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
   - Handles API communication
   - Processes text improvements

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
- Added OpenAI API integration with error handling
- Created clipboard management system
- Implemented global hotkey support (⌃⌥⌘C)
- Added settings UI for configuration

## Implementation Details

### AppState
The central state manager that:
- Coordinates between all services
- Manages settings persistence
- Handles error reporting
- Controls UI state

### Services
1. OpenAIService
   - Handles API communication with OpenAI
   - Manages text improvement requests
   - Provides error handling for API issues

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
- OpenAI API key (secure storage)
- Custom improvement prompt
- Error state

### Error Handling
Comprehensive error handling for:
- Missing API key
- No text selected
- API communication issues
- Text replacement failures
