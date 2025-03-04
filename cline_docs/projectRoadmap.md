# Butler Project Roadmap

## Project Overview
Butler is a macOS menubar application that helps improve text by correcting English mistakes using OpenAI API.

## High-Level Goals
- [ ] Create a menubar-only macOS application
- [ ] Implement global keyboard shortcut functionality
- [ ] Integrate clipboard management for text selection
- [ ] Set up OpenAI API integration
- [ ] Add error handling and user feedback
- [ ] Ensure smooth text replacement functionality

## Key Features
1. Global Keyboard Shortcut (control-option-cmd-c)
2. System clipboard integration
3. OpenAI-powered text improvement
4. Error feedback via popups
5. Selected text replacement
6. Settings menu in menubar:
   - OpenAI API key configuration
   - Customizable improvement prompt

## Completion Criteria
- Application runs in menubar only (no dock icon)
- Keyboard shortcut correctly captures selected text
- OpenAI integration successfully improves text
- Error handling covers:
  - No text selected
  - OpenAI API errors
- Improved text smoothly replaces original selection

## Completed Tasks
- [x] Created menubar-only macOS application
- [x] Implemented global keyboard shortcut (⌃⌥⌘C)
- [x] Added clipboard management for text handling
- [x] Integrated OpenAI API service
- [x] Implemented error handling with user feedback
- [x] Added settings UI for API key and prompt configuration
- [x] Set up accessibility permissions
