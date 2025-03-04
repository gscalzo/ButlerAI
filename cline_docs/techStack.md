# Technology Stack

## Core Technologies
- Swift 5.x
- SwiftUI for UI components
- AppKit for system integration

## Key Libraries/Frameworks Required
1. HotKey (for global keyboard shortcuts)
2. OpenAI Swift package

## Architecture Decisions
1. Menubar App Architecture
   - AppDelegate for managing app lifecycle
   - MenuBarManager for handling menubar presence
   - HotkeyManager for keyboard shortcuts
   - ClipboardManager for text handling
   - OpenAIService for API integration

2. Data Flow
   - Keyboard Shortcut → Clipboard Access → OpenAI Processing → Text Replacement

## System Requirements
- macOS 12.0 or later
- Internet connection for OpenAI API
- OpenAI API key

## External Dependencies Management
- Swift Package Manager for dependency management
