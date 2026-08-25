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
     - Pick a model — **GPT-5.6 Luna** (`gpt-5.6-luna`, the default: fastest and cheapest), Terra, Sol, or a custom model ID
     - Optionally tune the reasoning effort (Low by default — plenty for text polishing)
     - Advanced: point the Base URL at any OpenAI-compatible server

     **Ollama Setup**:
     - [Install Ollama](https://ollama.ai/download)
     - Select Ollama as your backend
     - Configure Ollama server URL (default: http://localhost:11434)
     - Choose from available local models

2. **Required Permissions**:
   - macOS asks for **Accessibility** access on first launch; it is needed for the global shortcut and for copying/pasting the selection. If no prompt appears and ButlerAI is not listed under Privacy & Security › Accessibility, click **+** there and choose ButlerAI from Applications (or drag it in from Finder)
   - You can check and fix this any time from **Settings → Permissions**: it shows whether access is granted and has one-click buttons to open System Settings, re-request access, or re-check
   - While access is missing, the menubar menu shows a warning banner with a "Fix…" shortcut to that tab

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

- macOS 15.2 or later
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
- Xcode 16.2 or later (required for builds)

### Building & Testing

```bash
make test                              # run unit tests (LOG_DIR=<dir> to redirect xcodebuild logs, default /tmp)
make build                             # unsigned debug build
make release DEVELOPMENT_TEAM=<TEAM>   # signed Release build (your Apple Developer Team ID)
make install DEVELOPMENT_TEAM=<TEAM>   # build + replace /Applications/Butler.app (old copy goes to the Trash)
make archive DEVELOPMENT_TEAM=<TEAM>   # Xcode archive, ready for -exportArchive
```

### Code Signing & Releases

Signing matters more than usual for this app: macOS binds the Accessibility permission to the app's
code signature, and the sandboxed app can only show the permission prompt thanks to an entitlement
exception. **[SIGNING.md](SIGNING.md)** covers everything in detail:

- creating Apple Development / Developer ID certificates and finding your Team ID
- local signed builds with `make install` (and why unsigned builds lose the Accessibility permission on every rebuild)
- manual Developer ID archive → export → DMG → notarization → stapling
- the GitHub Actions release workflow and the secrets it needs (`CERTIFICATE_BASE64`, `CERTIFICATE_PASSWORD`, `APPLE_DEVELOPER_ID`, `APPLE_DEVELOPER_PASSWORD`, `TEAM_ID`)
- the entitlements and how to verify a signature; troubleshooting permissions

Releases are built, signed, notarized and published automatically when a version tag is pushed:

```bash
git tag v1.2.0
git push origin v1.2.0
```

## License 📄

MIT License - See LICENSE file for details

## Support & Feedback 💭

Found a bug or have a feature request? Please open an issue!

---

<div align="center">

<img src="appstore.png" width="64" height="64" style="border-radius: 16px; margin: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">

_Made with ❤️ by Cline and an amazed human_ ✨

</div>
