# Code Signing, Notarization & Installation — Runbooks

Written to be executed by humans **or coding agents**. Every step is a shell command run from the
repository root, followed by the expected result and what to do if it differs. Steps tagged
**HUMAN** need a person (credentials, or a click inside System Settings): an agent must stop there,
say exactly what the person has to do, and wait.

Contents: [Ground rules](#0-ground-rules) · [Concepts](#1-concepts) · [Environment check](#2-environment-check) ·
[A: Local signed build & install](#runbook-a--local-signed-build--install) ·
[B: Accessibility permission / shortcut not working](#runbook-b--accessibility-permission--shortcut-not-working) ·
[C: Developer ID release (manual)](#runbook-c--developer-id-release-manual) ·
[D: Release via GitHub Actions](#runbook-d--release-via-github-actions) ·
[Reference](#reference) · [Failure table](#failure-table)

---

## 0. Ground rules

1. Run every command from the repository root. Commands are non-interactive unless tagged **HUMAN**.
2. Use `/usr/bin/log` (full path) for unified-log queries — a shell alias/function named `log` may shadow it and return nothing.
3. `~/.Trash` and `~/Library/Application Support/com.apple.TCC/` are unreadable from a terminal without Full Disk Access. Do not try to read or edit the TCC database; use `tccutil` and the unified log instead.
4. Never switch privacy toggles in System Settings on the user's behalf (no UI scripting of System Settings). Open the pane, then hand over.
5. Never run `make test` (or any ad-hoc build) between `tccutil reset` and launching the real app — see [Concepts](#1-concepts) item 3.
6. Do not delete `/Applications/Butler.app` with `rm`; `make install` moves the old copy to the Trash.
7. Do not commit values from `ExportOptions.plist` or `DEVELOPMENT_TEAM` that belong to someone else's account; use placeholders in docs.
8. Expected outputs below are patterns; team IDs, names and hashes will differ.

## 1. Concepts

1. **Accessibility permission is bound to the code signature.** macOS (TCC) records the app's *designated requirement* when the permission row is created. Certificate-signed builds have `identifier "<bundle id>" and anchor apple generic and certificate leaf = <certificate>`, so every rebuild with the same certificate keeps the permission.
2. **Ad-hoc/unsigned builds lose it every time.** Their requirement is `cdhash H"…"` — one exact binary. Each rebuild is a new app to TCC.
3. **TCC keys rows by bundle ID and binds each row to the first binary that asked.** The unit-test host is ad-hoc signed with the same bundle ID; if it touched the Accessibility API it would create/poison rows. The app therefore uses `DeniedAccessibilityPermissionChecker` under tests. Several rows with the same name can exist; only the one matching the running binary counts.
4. **The prompt needs a sandbox exception.** The dialog is drawn by `com.apple.universalaccessAuthWarn`; the sandbox blocks it unless it is listed in `com.apple.security.temporary-exception.mach-lookup.global-name` (`Butler/Butler.entitlements`). Missing exception ⇒ no dialog, no row, user must add the app with **+**.
5. **Distribution needs Developer ID + notarization.** Gatekeeper accepts downloaded apps only if Developer-ID-signed and notarized. Locally built apps are not quarantined, so a development-signed `make install` runs fine on the build machine but must not be shipped.
6. **Signing identity precedence.** `make release/install/archive` use automatic signing with `DEVELOPMENT_TEAM` (command-line override > project setting). `make test/build` run with signing disabled (ad-hoc), on purpose, so they work without certificates.

## 2. Environment check

Run all of these before any runbook; fix anything that does not match.

| # | Command | Expect | If not |
| --- | --- | --- | --- |
| 1 | `xcodebuild -version` | `Xcode 16.2` or newer | Install/select Xcode: `sudo xcode-select -s /Applications/Xcode.app` |
| 2 | `which xcsift rg` | two paths | `brew install xcsift ripgrep` (needed by the Makefile) |
| 3 | `security find-identity -v -p codesigning` | at least one `"Apple Development: …"` line; for releases also `"Developer ID Application: … (<TEAM_ID>)"` | **HUMAN**: create certificates (Xcode → Settings → Accounts → Manage Certificates… → +, or developer.apple.com). Agents cannot create certificates. |
| 4 | `grep -m1 "DEVELOPMENT_TEAM" Butler.xcodeproj/project.pbxproj` | `DEVELOPMENT_TEAM = <10 chars>;` | Pass `DEVELOPMENT_TEAM=<Team ID>` to make targets (the ID is the value in parentheses in step 3), or set the team in Xcode → target Butler → Signing & Capabilities |
| 5 | `grep -c universalaccessAuthWarn Butler/Butler.entitlements` | `1` | Re-add the exception (see [Reference → Entitlements](#entitlements)) |
| 6 | `make test LOG_DIR=./.logs 2>&1 \| tail -3` | `"status" : "success"` and `tests_run: N` | Fix the build/tests first (AGENTS.md rules) |

## Runbook A — Local signed build & install

**Goal:** a certificate-signed Release build at `/Applications/Butler.app`, launched, with the Accessibility prompt shown.

1. Build and install (`DEVELOPMENT_TEAM=` optional if the project's team matches an identity from check 3):
   ```bash
   make install DEVELOPMENT_TEAM=<TEAM_ID> LOG_DIR=./.logs 2>&1 | tail -6
   ```
   Expect the last lines: `built: ./DerivedData/Build/Products/Release/Butler.app (<version>)`, optionally `moved previous app to …/.Trash`, `installed: /Applications/Butler.app (<version>)`.
   If `"status" : "failed"` appears, read `./.logs/butler_make_release.log`; signing errors mention "No signing certificate" / "doesn't match" — see the [Failure table](#failure-table).
2. Verify the installed app:
   ```bash
   make verify-signing
   ```
   Expect `signature: valid`, an `Authority=Apple Development: …` (or `Developer ID Application: …`) line, `entitlements: accessibility prompt exception present`, `requirement: certificate-based …`, and the version. Any `MISSING`/`INVALID`/`cdhash-only` line means stop and fix (the target exits non-zero).
3. Launch and confirm the permission flow started:
   ```bash
   open -a /Applications/Butler.app; sleep 5
   tail -n 15 ~/Library/Containers/uk.co.effectivecode.Butler/Data/Library/Logs/ButlerAI.log
   ```
   Expect, in order: `Accessibility permission service initialized (granted: false|true)`, and if false: `Requesting accessibility access from macOS`, `Started polling accessibility permission every 2.0s`, `Setting up hotkey (⌃⌥⌘C)`.
   - If `granted: true` → done (`Registering global hotkey` follows within a second).
   - If `granted: false` → continue with Runbook B step 3 (the prompt should be on screen).

## Runbook B — Accessibility permission / shortcut not working

**Goal:** the running `/Applications/Butler.app` is trusted for Accessibility, so ⌃⌥⌘C fires.

1. Diagnose from the app log (no guessing):
   ```bash
   grep -E "initialized \(granted|Requesting|granted|Registering|removed" \
     ~/Library/Containers/uk.co.effectivecode.Butler/Data/Library/Logs/ButlerAI.log | tail -5
   ```
   - Last `initialized (granted: true)` / `Accessibility permission granted` + `Registering global hotkey` → permission is fine; the problem is elsewhere (selection empty, API key, network — check the rest of the log).
   - `granted: false` and no later `granted` line → continue.
2. Check that the installed build can prompt and has a stable requirement:
   ```bash
   make verify-signing
   ```
   If it reports a missing `universalaccessAuthWarn` exception or a `cdhash-only` requirement, rebuild with Runbook A first, then return here.
3. Confirm what macOS did with the request (last launch):
   ```bash
   /usr/bin/log show --last 10m --info --debug --style compact --predicate 'process == "tccd"' \
     | grep "uk.co.effectivecode.Butler" | grep -E "Handling access request|AUTHREQ_RESULT" | tail -4
   /usr/bin/log show --last 10m --style compact --predicate 'process == "kernel" AND eventMessage CONTAINS "Butler" AND eventMessage CONTAINS "deny"' | tail -3
   ```
   - A `deny(1) mach-lookup com.apple.universalaccessAuthWarn` line → the running build lacks the entitlement exception (step 2).
   - `AUTHREQ_RESULT … authValue=1` with no deny → the prompt was shown; the row exists but is off, or the user dismissed the dialog.
   - `authValue=2` → allowed; if the app still logs `granted: false`, the row is bound to another binary (step 4).
4. Reset stale rows and re-prompt (only when steps 1–3 show the row is missing/mismatched). Do **not** run `make test` between these two commands:
   ```bash
   pkill -x Butler; sleep 2
   tccutil reset Accessibility uk.co.effectivecode.Butler
   open -a /Applications/Butler.app; sleep 5
   ```
   Expect `Successfully reset Accessibility approval status for uk.co.effectivecode.Butler` (printed once per removed row) and, in the app log, `Requesting accessibility access from macOS`.
5. **HUMAN** — grant the permission. Open the pane for the person:
   ```bash
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
   ```
   Tell them: *"Switch **Butler** on under Privacy & Security › Accessibility. If it is not listed, click **+** and choose /Applications/Butler.app (or drag it in from Finder). If it is listed and already on, switch it off and on."* Do not toggle it yourself.
6. Confirm (the app polls every 2 s, no relaunch needed):
   ```bash
   sleep 5; grep -E "permission granted|Registering global hotkey" \
     ~/Library/Containers/uk.co.effectivecode.Butler/Data/Library/Logs/ButlerAI.log | tail -2
   ```
   Expect both lines. Then ask the person to select text and press ⌃⌥⌘C.

## Runbook C — Developer ID release (manual)

**Goal:** a notarized, stapled `build/ButlerAI.dmg` identical to what CI produces. Needs a `Developer ID Application` identity (check 3).

1. Set the export options (edit `ExportOptions.plist`; keep `method`/`signingStyle`):
   ```xml
   <key>teamID</key>             <string>YOUR_TEAM_ID</string>
   <key>signingCertificate</key> <string>Developer ID Application: Your Name or Company</string>
   ```
   `signingCertificate` must equal the identity's common name from check 3 **without** the `(TEAM_ID)` suffix.
2. Archive:
   ```bash
   xcodebuild -project Butler.xcodeproj -scheme Butler -configuration Release \
     -archivePath build/Butler.xcarchive archive \
     DEVELOPMENT_TEAM="YOUR_TEAM_ID" CODE_SIGN_IDENTITY="Developer ID Application" CODE_SIGN_STYLE=Manual \
     2>&1 | xcsift -w | tail -6
   ```
   Expect `"status" : "success"` and `build/Butler.xcarchive` to exist.
3. Export:
   ```bash
   xcodebuild -exportArchive -archivePath build/Butler.xcarchive -exportPath build/export \
     -exportOptionsPlist ExportOptions.plist 2>&1 | tail -5
   ```
   Expect `EXPORT SUCCEEDED` and `build/export/Butler.app`.
4. Verify the exported app:
   ```bash
   make verify-signing APP=build/export/Butler.app
   codesign -dv --verbose=2 build/export/Butler.app 2>&1 | grep -E "Authority=Developer ID Application|flags=.*runtime"
   ```
   Expect both grep lines (Developer ID authority, hardened `runtime` flag).
5. Package:
   ```bash
   hdiutil create -volname "ButlerAI" -srcfolder build/export/Butler.app -ov -format UDZO build/ButlerAI.dmg
   ```
6. **HUMAN** — notarization credentials. Ask the person to run once (an app-specific password, never the Apple ID password):
   ```bash
   xcrun notarytool store-credentials "butler-notary" --apple-id "you@example.com" --team-id "YOUR_TEAM_ID" --password "xxxx-xxxx-xxxx-xxxx"
   ```
   Agents must not ask for or store the password themselves.
7. Notarize and staple:
   ```bash
   xcrun notarytool submit build/ButlerAI.dmg --keychain-profile "butler-notary" --wait 2>&1 | tail -4
   xcrun stapler staple build/ButlerAI.dmg
   ```
   Expect `status: Accepted` then `The staple and validate action worked!`. On `status: Invalid`: `xcrun notarytool log <submission-id> --keychain-profile "butler-notary"` and fix the listed issues (usually a missing hardened runtime or an unsigned nested binary).
8. Final check:
   ```bash
   spctl --assess --type open --context context:primary-signature -v build/ButlerAI.dmg
   ```
   Expect `accepted` and `source=Notarized Developer ID`.

## Runbook D — Release via GitHub Actions

`.github/workflows/release.yml` runs Runbook C steps 2–7 on every pushed tag matching `v*` and attaches the DMG to a GitHub release.

1. Repository secrets (Settings → Secrets and variables → Actions). **HUMAN** for all values:

   | Secret | Value | How the person obtains it |
   | --- | --- | --- |
   | `CERTIFICATE_BASE64` | Developer ID Application certificate + private key, base64 `.p12` | Keychain Access → My Certificates → right-click the certificate → Export… → `.p12` with a password; then `base64 -i Certificates.p12 \| pbcopy` |
   | `CERTIFICATE_PASSWORD` | password chosen at export | — |
   | `APPLE_DEVELOPER_ID` | Apple ID email used for notarization | — |
   | `APPLE_DEVELOPER_PASSWORD` | app-specific password for that Apple ID | account.apple.com → Sign-In and Security → App-Specific Passwords |
   | `TEAM_ID` | 10-character Team ID | developer.apple.com → Membership details |

   `ExportOptions.plist` (`teamID`, `signingCertificate`) must match the same certificate — it is read from the repository.
2. Version: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in `Butler.xcodeproj/project.pbxproj` (app target). Bump both (build number must increase) and make sure the tag matches `MARKETING_VERSION`:
   ```bash
   grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Butler.xcodeproj/project.pbxproj | sort -u
   ```
3. Tag and push (after the version bump is committed):
   ```bash
   git tag v<MARKETING_VERSION>
   git push origin v<MARKETING_VERSION>
   ```
4. Watch the run (`gh run watch` or the Actions tab). Expect a green run and a release with `ButlerAI.dmg`. On failure, the job log lines prefixed `[BUTLER]` name the failing stage (build / export / notarize / staple).

## Reference

### Makefile targets and variables

| Target | Signing | Output |
| --- | --- | --- |
| `make test` | disabled (ad-hoc) | runs unit tests; `tests_run: N` |
| `make build` | disabled (ad-hoc) | Debug app in `DerivedData` |
| `make release` | automatic | `DerivedData/Build/Products/Release/Butler.app` |
| `make install` | automatic | replaces `/Applications/Butler.app`; old copy → Trash |
| `make archive` | automatic | `build/Butler.xcarchive` |
| `make verify-signing [APP=path]` | — | prints signature/entitlement/requirement/version checks; non-zero exit on any problem |

Variables: `DEVELOPMENT_TEAM=<Team ID>` (signing team), `LOG_DIR=<dir>` (xcodebuild logs, default `/tmp`), `APP=<path>` (for `verify-signing`, default `/Applications/Butler.app`).

### Entitlements

`Butler/Butler.entitlements`, applied to every signed build (`ENABLE_HARDENED_RUNTIME = YES` in the project is required for notarization):

| Entitlement | Why |
| --- | --- |
| `com.apple.security.app-sandbox` | App is sandboxed |
| `com.apple.security.network.client` | OpenAI API / local Ollama |
| `com.apple.security.network.server` | historical, kept for existing installs |
| `com.apple.security.files.user-selected.read-only` | standard sandbox file access |
| `com.apple.security.automation.apple-events` + temporary exception `com.apple.systemevents` | Apple Events automation |
| mach-lookup exception `com.apple.coreservices.launchservicesd` | Launch Services from the sandbox |
| mach-lookup exception `com.apple.universalaccessAuthWarn` | **shows the Accessibility permission prompt** (Concepts 4) |

### Verification commands

```bash
codesign --verify --deep --strict /Applications/Butler.app && echo OK   # integrity
codesign -dv --verbose=2 /Applications/Butler.app                       # Identifier=, Authority=, TeamIdentifier=, flags=
codesign -d --entitlements :- /Applications/Butler.app | plutil -p -    # embedded entitlements
codesign -d -r- /Applications/Butler.app                                # designated requirement (what TCC binds to)
spctl --assess --type execute -v /Applications/Butler.app               # "accepted" only for notarized Developer ID builds; "rejected" is normal for local dev builds
```

### Where things are

- App log: `~/Library/Containers/uk.co.effectivecode.Butler/Data/Library/Logs/ButlerAI.log` (also *Show Logs* in the menubar menu)
- TCC decisions: `/usr/bin/log show --last 10m --info --debug --predicate 'process == "tccd"' | grep uk.co.effectivecode.Butler`
- Sandbox denials: `/usr/bin/log show --last 10m --predicate 'process == "kernel" AND eventMessage CONTAINS "Butler"'`
- Bundle identifier: `uk.co.effectivecode.Butler` (`PRODUCT_BUNDLE_IDENTIFIER`); changing it also changes the container path, log path and TCC rows

## Failure table

| Symptom | Cause | Action |
| --- | --- | --- |
| `No signing certificate "Mac Development" found` / `doesn't match any valid certificate` | no identity for the team | Check 3; pass the right `DEVELOPMENT_TEAM=`; **HUMAN** creates the certificate |
| `errSecInternalComponent` while signing in a script | keychain locked | `security unlock-keychain ~/Library/Keychains/login.keychain-db` (**HUMAN** enters the password) |
| `make verify-signing` → `requirement: cdhash-only` | build was ad-hoc (signing disabled) | rebuild with `make install` (not `make build`) |
| `make verify-signing` → `MISSING com.apple.universalaccessAuthWarn` | entitlement exception removed | restore it in `Butler/Butler.entitlements`, rebuild |
| App log `granted: false` forever after enabling in System Settings | row bound to another binary (test host / old signature) | Runbook B step 4, then **HUMAN** step 5 |
| No prompt and app not listed under Accessibility | sandbox blocked the prompt, or ad-hoc build | Runbook B steps 2–3; fallback: **HUMAN** adds the app with **+** |
| `spctl … rejected` for a local build | not notarized | expected for development builds; only relevant for distributed DMGs |
| `notarytool` → `status: Invalid` | hardened runtime off, unsigned nested code, or bad entitlements | `notarytool log <id>`; fix; re-run Runbook C from step 2 |
| `log show` prints nothing / "too many arguments" | shell function shadows `log` | use `/usr/bin/log` |
| `hdiutil: … Resource busy` | DMG still mounted | `hdiutil detach /Volumes/ButlerAI` then retry |
