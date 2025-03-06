# Butler Project Roadmap

## Project Overview
Butler is a macOS menubar application that helps improve text by correcting English mistakes using OpenAI API.

## High-Level Goals
- [x] Create a menubar-only macOS application
- [x] Implement global keyboard shortcut functionality
- [x] Integrate clipboard management for text selection
- [x] Set up OpenAI API integration
- [x] Add error handling and user feedback
- [x] Ensure smooth text replacement functionality
- [x] Add Ollama backend support

## Key Features
1. Global Keyboard Shortcut (control-option-cmd-c)
2. System clipboard integration
3. OpenAI-powered text improvement
4. Error feedback via popups
5. Selected text replacement
6. Settings menu in menubar:
   - AI backend selection (OpenAI/Ollama)
   - OpenAI API key configuration
   - Ollama server URL configuration
   - Model selection for Ollama
   - Customizable improvement prompt

## Completion Criteria
- Application runs in menubar only (no dock icon)
- Keyboard shortcut correctly captures selected text
- AI integration (OpenAI/Ollama) successfully improves text
- Error handling covers:
  - No text selected
  - API errors
  - Connection errors
  - Model loading errors
- Improved text smoothly replaces original selection
- Seamless switching between AI backends

## Completed Tasks
- [x] Created menubar-only macOS application
- [x] Implemented global keyboard shortcut (⌃⌥⌘C)
- [x] Added clipboard management for text handling
- [x] Integrated OpenAI API service
- [x] Implemented error handling with user feedback
- [x] Added settings UI for API key and prompt configuration
- [x] Set up accessibility permissions
- [x] Added Ollama backend support
- [x] Implemented model selection for Ollama
- [x] Updated settings UI for backend selection
