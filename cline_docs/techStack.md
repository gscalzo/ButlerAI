# Technology Stack

## Core Technologies
- Swift 5.x
- SwiftUI for UI components
- AppKit for system integration

## Key Libraries/Frameworks Required
1. HotKey (for global keyboard shortcuts)
2. OpenAI Swift package
3. URLSession for API communication with both OpenAI and Ollama

## Architecture Decisions
1. Menubar App Architecture
   - AppDelegate for managing app lifecycle
   - MenuBarManager for menubar presence
   - HotkeyManager for keyboard shortcuts
   - ClipboardManager for text handling
   - OpenAIService for both OpenAI and Ollama integration
   - Dynamic model selection and backend switching

2. Data Flow
   - Keyboard Shortcut → Clipboard Access → AI Processing (OpenAI/Ollama) → Text Replacement

## System Requirements
- macOS 12.0 or later
- For OpenAI backend:
  - Internet connection
  - OpenAI API key
- For Ollama backend:
  - Local Ollama installation
  - Available AI models

## External Dependencies Management
- Swift Package Manager for dependency management
