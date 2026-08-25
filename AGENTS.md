# ButlerAI Agent Notes

## Product Overview
ButlerAI is a macOS menubar app that improves selected text using AI. It runs without a dock icon, listens for a global hotkey (⌃⌥⌘C), copies the current selection, sends it to an AI backend (OpenAI or local Ollama), then pastes the improved text back while preserving clipboard contents.

## High-Level Architecture
- **UI shell:** SwiftUI `MenuBarExtra` with a tabbed settings window (AI / Prompt / Permissions) and a logs window.
- **State orchestration:** `AppState` coordinates services, processing state, errors, and window lifecycle.
- **Services layer:** Accessibility permission monitoring, hotkey handling, clipboard operations, AI requests (shared `HTTPJSONClient`), language handling, logging.
- **Settings persistence:** `@AppStorage` in `SettingsService` (injectable `UserDefaults`), API key in the Keychain via `SecretStoring`, versioned one-time migrations.

## Key Components
- `Butler/ButlerApp.swift`
  - `AppState` owns `HotkeyManager`, `ClipboardManager`, `OpenAIService`, `LanguageService`, `SettingsService`.
  - Handles menu bar UI, settings window, log window, and end-to-end “improve text” flow.
  - Uses `MenuBarExtra` with animated icon during processing.

- `Butler/Services/AccessibilityPermissionService.swift`
  - `@MainActor` observable source of truth for the macOS Accessibility permission (`isGranted`).
  - Polls only while access is missing, refreshes when the app becomes active, can prompt (`requestAccess()`) and open System Settings.
  - `AccessibilityPermissionChecking` protocol makes it testable without touching the real permission.

- `Butler/Services/HotkeyManager.swift`
  - `KeyboardShortcutSpec` is the single definition of ⌃⌥⌘C (`HotkeyManager.improveTextShortcut`).
  - Subscribes to the permission service and (un)registers the global `NSEvent` monitor as access is granted/revoked. No alerts or timers of its own.

- `Butler/Views/AccessibilityPermissionView.swift`
  - `AccessibilityPermissionView`: Settings → Permissions section (status, how-to, Open System Settings / Request Access / Check Again).
  - `AccessibilityStatusBanner`: compact warning shown in the menubar menu while access is missing.

- `Butler/Services/ClipboardManager.swift`
  - Simulates **Cmd+C** to capture selection and **Cmd+V** to paste through the injectable `KeystrokeSimulating` protocol.
  - Preserves and restores previous clipboard contents; `restorePreviousClipboard()` must be called if the flow fails after the copy.
  - Treats an unchanged pasteboard after Cmd+C as "no selection" (never improves stale clipboard content).

- `Butler/Services/OpenAIService.swift` (`OpenAIClient`)
  - OpenAI-only client (Ollama lives in `OllamaClient`). Endpoint: `.../v1/chat/completions` (custom base URL supported).
  - GPT-5-family / o-series models get `max_completion_tokens` (16k, shared with reasoning) + `reasoning_effort`; other models get `max_tokens` + `temperature` (`OpenAIClient.usesReasoningParameters(model:)`). `reasoning_effort: none` is only sent to the curated GPT-5.6 models (`supportedReasoningEfforts(model:)`); `finish_reason: "length"` is rejected as `AIServiceError.responseTruncated` so a cut-off rewrite is never pasted.
  - Default model: `AIModelConstants.defaultOpenAIModel` = `gpt-5.6-luna`; known options in `OpenAIModelCatalog`.

- `Butler/Services/OllamaClient.swift`
  - Endpoint: `.../api/chat`; models list: `.../api/tags`.

- `Butler/Services/HTTPJSONClient.swift` + `Butler/Services/AIServiceError.swift`
  - Shared JSON transport (injectable `URLSession`, 180s timeout, decodes both OpenAI `{error:{message}}` and Ollama `{error:"…"}` envelopes) and the `AIServiceError` enum used by both clients.
  - `HTTPURLNormalizer` accepts scheme-less server addresses (`localhost:1234/v1`, `myhost:11434`). `Info.plist` allows local networking (`NSAllowsLocalNetworking`) so plain-http LAN servers work.

- `Butler/Services/LanguageService.swift`
  - Detects Italian text using `NaturalLanguage`.
  - If Italian, asks the AI to translate and improve; otherwise improves directly.

- `Butler/Services/LoggerService.swift` + `Butler/Views/LogView.swift`
  - In-memory structured logs with type (info/warning/error).
  - Log window supports search, filtering, auto-scroll, copy, clear.

- `Butler/Views/SettingsView.swift`
  - `TabView` (`SettingsTab`: ai / prompt / permissions); `AppState.settingsTab` selects the tab programmatically.
  - AI tab: backend switcher, OpenAI key, model picker (catalog + Custom…), reasoning effort, base URL; Ollama URL + model picker with refresh.
  - Prompt tab: editor + Reset to Default. Permissions tab: `AccessibilityPermissionView` + shortcut.

- `Butler/Models/AIConfiguration.swift`
  - `AIBackendType`, `AIModelConstants` (default `gpt-5.6-luna`, previous defaults for migration), `OpenAIModelCatalog`, `OpenAIReasoningEffort`.

## Data Flow (Runtime)
1. User presses ⌃⌥⌘C (only registered while Accessibility access is granted).
2. `HotkeyManager` triggers `AppState.improveSelectedText()`.
3. `ClipboardManager` captures selection via Cmd+C.
4. `LanguageService` optionally translates Italian and calls the active `TextImproving` client.
5. Improved text returned to `ClipboardManager` for Cmd+V paste.
6. Previous clipboard contents are restored (also on failure).

## Settings & Persistence
`SettingsService` stores (keys in `SettingsService.Keys`):
- `openaiKey` (Keychain)
- `openaiBaseURL`
- `aiBackend` (OpenAI / Ollama)
- `ollamaURL`
- `openAIModel` / `ollamaModel` (per-backend; `activeModel` picks the current one)
- `openAIReasoningEffort`
- `improvementPrompt`
- `settingsSchemaVersion` — bump `currentSchemaVersion` and extend `migrateIfNeeded()` for one-time migrations (v2 split the legacy `selectedModel` and moved old default models to Luna).

## Signing, Installing & Permissions (agent runbooks)
`SIGNING.md` is written as step-by-step runbooks with expected outputs; follow it instead of improvising:
- Environment check → `SIGNING.md` §2 (identities, team, entitlement, tests).
- Build & install a signed app → Runbook A (`make install DEVELOPMENT_TEAM=<Team ID>`, then `make verify-signing`).
- "Shortcut doesn't work" / Accessibility → Runbook B (log-driven; `tccutil reset` only when the log proves a stale row; granting is a **HUMAN** step — never toggle System Settings yourself).
- Releases → Runbook C (manual Developer ID) / D (tag-triggered CI).
Ground rules that bite agents: use `/usr/bin/log` (a `log` shell function may shadow it); `~/.Trash` and the TCC database are unreadable from the terminal; never run `make test` between `tccutil reset` and launching the app; never `rm` `/Applications/Butler.app` (`make install` moves it to the Trash).

## Permissions & OS Integration
- Requires **Accessibility** permissions for global key monitoring and clipboard events.
- The app is sandboxed; the Accessibility prompt is drawn by the `com.apple.universalaccessAuthWarn` service, which the sandbox blocks unless it is listed in `com.apple.security.temporary-exception.mach-lookup.global-name` (it is, in `Butler.entitlements`). Without it the prompt silently never appears and users must add the app with “+”.
- macOS (TCC) keys Accessibility rows by bundle ID and stores the code requirement of the *first* process that asked. The ad-hoc-signed unit-test host shares the bundle ID, so under tests the app uses `DeniedAccessibilityPermissionChecker` and never calls `AXIsProcessTrusted`. If the hotkey stops working after re-signing/reinstalling: `tccutil reset Accessibility uk.co.effectivecode.Butler`, relaunch the app, re-enable it in System Settings.
- Uses `AXIsProcessTrustedWithOptions` for prompting and `NSEvent.addGlobalMonitorForEvents` for hotkey capture.

## Observed Quirks / Implementation Notes
- GPT-5-family models reject `max_tokens`/`temperature` on Chat Completions — keep the parameter split in `OpenAIClient` when adding models.
- Accessibility polling is intentionally cheap (2s, only while not granted) and stops itself once granted.
- Modal alerts go through `AlertPresenter`.
- Version: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the pbxproj (app target); shown in the menubar menu via `AppInfo`. `Butler/Info.plist` is merged into the generated plist (`INFOPLIST_FILE`).

## Build & Test
- Open `Butler.xcodeproj` in Xcode (deployment target macOS 15.2).
- Tests live in `ButlerTests` (UI tests removed). Network clients are tested with `MockURLProtocol`; settings tests use an isolated `UserDefaults` suite and an in-memory `SecretStoring`.

## Common Entry Points
- App: `Butler/ButlerApp.swift`
- AI: `Butler/Services/OpenAIService.swift`
- Settings: `Butler/Views/SettingsView.swift`
- Clipboard: `Butler/Services/ClipboardManager.swift`
- Hotkey: `Butler/Services/HotkeyManager.swift`
- Accessibility permission: `Butler/Services/AccessibilityPermissionService.swift`
- Logs UI: `Butler/Views/LogView.swift`

# unit tests
Use XCTest for unit tests.
Implement unit tests to ensure that the code works as intended.
Run the tests before making any changes, add tests to verify the changes, and ensure that the tests pass before considering the session complete.

# xcodebuild 
To save context, use the tool xcsift to format the output of xcodebuild or Swift. 
Here is the help:
OVERVIEW: A Swift tool to parse and format xcodebuild output for coding agents
xcsift reads xcodebuild output from stdin and outputs structured JSON.
Important: Always use 2>&1 to redirect stderr to stdout. This ensures all
compiler errors, warnings, and build output are captured.
Examples:
xcodebuild build 2>&1 | xcsift -w
xcodebuild test 2>&1 | xcsift -w
swift build 2>&1 | xcsift -w
swift test 2>&1 | xcsift -w

# Structure hygiene
Fix all errors, warnings, and failed tests, even if they are not related to the current changes being made.

# grep or search text 
You are operating in an environment where ast-grep is installed. For any code search that requires understanding of syntax or code structure, you should default to using ast-grep --lang [language] -p '<pattern>'. Adjust the --lang flag as needed for the specific programming language. Avoid using text-only search tools unless a plain-text search is explicitly requested.

# tests scope
UI tests have been removed; unit tests are run via `make test`.

# Makefile
Use `Makefile` targets for common tasks:
- `make test` (unit tests only, executes tests; `LOG_DIR=<dir>` overrides the log location, default `/tmp`)
- `make test-build` (build-for-testing only)
- `make build`
- `make release` (signed Release build, automatic signing) / `make install` (build Release and replace `/Applications/Butler.app`; the old copy is moved to the Trash). Add `DEVELOPMENT_TEAM=<Team ID>` to sign with another team. Signing, notarization and the CI release flow are documented in `SIGNING.md`.
- `make archive`
- `make clean`

# test command
Use `make test` to execute unit tests (includes xcsift formatting and validates that the log includes the test count; prints `tests_run`).
