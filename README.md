<div align="center">

```
__________        __  .__                  _____  .___ 
\______   \__ ___/  |_|  |   ___________  /  _  \ |   |
 |    |  _/  |  \   __\  | _/ __ \_  __ \/  /_\  \|   |
 |    |   \  |  /|  | |  |_\  ___/|  | \/    |    \   |
 |______  /____/ |__| |____/\___  >__|  \____|__  /___|
        \/                      \/              \/      
```

<img src="appstore.png" width="128" height="128" style="border-radius: 20%; box-shadow: 0 8px 16px rgba(0,0,0,0.1);">

### _Elevate Your Writing with AI Precision_ ✨

</div>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#examples">Examples</a> •
  <a href="#support--feedback">Support</a>
</p>

# ButlerAI - Your Text Enhancement Assistant 🎩

ButlerAI is an elegant macOS menubar application that helps you improve your writing with the power of AI. Just select any text, press a shortcut, and watch as your text is refined and enhanced.

## Features 🌟

- **Global Keyboard Shortcut** (⌃⌥⌘C) - Improve text anywhere, in any application
- **AI-Powered Enhancement** - Choose between OpenAI's API or local Ollama models for intelligent text improvements
- **Seamless Integration** - Lives in your menubar for quick access
- **Original Context Preservation** - Maintains the original meaning and tone while improving clarity
- **Clipboard Protection** - Preserves your clipboard content during operations

## Installation 🚀

1. Download ButlerAI.dmg from the [Releases page](../../releases/latest)
2. Open the DMG file
3. Drag ButlerAI.app to your Applications folder
4. Launch ButlerAI from Applications
5. Configure your OpenAI API key in settings

## Setup ⚙️

1. **First Launch**:
   - Click the wand icon (✨) in your menubar
   - Open Settings
   - Choose your preferred AI backend:

     **OpenAI Setup**:
     - Enter your OpenAI API key
     - Select a model (default: gpt-4o-mini)

     **Ollama Setup**:
     - [Install Ollama](https://ollama.ai/download)
     - Select Ollama as your backend
     - Configure Ollama server URL (default: http://localhost:11434)
     - Choose from available local models

2. **Required Permissions**:
   - Grant Accessibility permissions when prompted
   - These are needed for the keyboard shortcut functionality

## Usage 📝

1. Select any text in any application
2. Press ⌃⌥⌘C (Control + Option + Command + C)
3. Watch as your text is magically improved!

## Examples 🎯

Regular text improvement:
```
i think that this sentence could use some work because its not very good written
```
↓
```
I believe this sentence could be improved as it contains several grammatical errors and lacks clarity.
```

AI instruction improvement:
```
tell me a story about a dragon that lives in SF and works as a software engineer
```
↓
```
Please write a story about a dragon residing in San Francisco who works as a software engineer.
```

## Error Messages 🔍

ButlerAI provides clear feedback when something goes wrong:
- Missing API key notifications
- No text selected warnings
- Network connectivity issues
- API error details

## Requirements 📋

- macOS 12.0 or later
- One of the following:
  - OpenAI API key (for OpenAI backend)
  - Ollama installation (for local AI backend)
- Internet connection (for OpenAI backend only)

## Privacy & Security 🔒

- Text processing can happen either:
  - Through OpenAI's secure API
  - Locally using Ollama (complete privacy, no data leaves your machine)
- No data is stored permanently
- Your clipboard content is preserved
- API key is stored securely in macOS keychain

## Development 🛠️

Built with:
- SwiftUI
- AppKit Integration
- OpenAI API / Ollama Integration
- Secure Networking
- Xcode 16.2.0 (required for builds)

### Building Releases

Releases are automatically built and signed when pushing version tags:

1. **Required Secrets**:
   - `CERTIFICATE_BASE64`: Developer ID Application certificate
   - `CERTIFICATE_PASSWORD`: Certificate export password
   - `APPLE_DEVELOPER_ID`: Apple ID email
   - `APPLE_DEVELOPER_PASSWORD`: App-specific password
   - `TEAM_ID`: Apple Developer Team ID

2. **Creating a Release**:
   ```bash
   git tag v1.0.0  # Use appropriate version
   git push origin v1.0.0
   ```

The GitHub Action will automatically:
- Build the app
- Sign with Developer ID
- Create notarized DMG
- Create GitHub release

## License 📄

MIT License - See LICENSE file for details

## Support & Feedback 💭

Found a bug or have a feature request? Please open an issue!

---

<div align="center">

<img src="appstore.png" width="64" height="64" style="border-radius: 16px; margin: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">

_Made with ❤️ by Cline and an amazed human_ ✨

</div>
