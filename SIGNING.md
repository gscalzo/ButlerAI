# Code Signing, Notarization & Installation

ButlerAI needs macOS **Accessibility** access (to watch the global shortcut and to paste the improved
text). macOS ties that permission to the app's **code signature**, so how the app is signed decides
whether the permission survives a rebuild, whether the system prompt appears at all, and whether other
people can open the app you distribute. This document explains every signing path the project supports.

- [Why signing matters for this app](#why-signing-matters-for-this-app)
- [Prerequisites](#prerequisites)
- [1. Local signed build (`make install`)](#1-local-signed-build-make-install)
- [2. Developer ID release build (manual)](#2-developer-id-release-build-manual)
- [3. Automated release (GitHub Actions)](#3-automated-release-github-actions)
- [Entitlements explained](#entitlements-explained)
- [Verifying a signature](#verifying-a-signature)
- [Troubleshooting](#troubleshooting)

## Why signing matters for this app

1. **Accessibility permission is bound to the signature.** macOS (TCC) stores the app's *designated
   requirement* when the permission row is created. For a certificate-signed build that requirement is
   `identifier "<bundle id>" and anchor apple generic and certificate leaf = <your certificate>`, which
   every future build made with the same certificate satisfies — the permission survives rebuilds and
   reinstalls. An **ad-hoc/unsigned** build gets a `cdhash`-only requirement that matches exactly one
   binary: every rebuild is a "new app" and the permission must be granted again.
2. **The permission prompt needs a sandbox exception.** The app is sandboxed. The dialog that asks for
   Accessibility access is drawn by the `com.apple.universalaccessAuthWarn` system service, which the
   sandbox blocks unless it is listed in `com.apple.security.temporary-exception.mach-lookup.global-name`
   (it is, in `Butler/Butler.entitlements`). Without it the prompt silently never appears and users have
   to add the app by hand with **+** in System Settings.
3. **Distribution needs Developer ID + notarization.** Gatekeeper only opens downloaded apps that are
   signed with a *Developer ID Application* certificate and notarized by Apple. Locally built apps are
   exempt (they are not quarantined), which is why a development-signed `make install` works on your own
   machine but must not be shipped.

## Prerequisites

- Xcode 16.2 or later with the command line tools (`xcode-select --install`).
- An [Apple Developer Program](https://developer.apple.com/programs/) membership (required for
  Developer ID and notarization; a free account is enough for local development signing).
- Certificates in your login keychain:
  - **Apple Development** — for local builds. Easiest: Xcode → Settings → Accounts → select your
    account → *Manage Certificates…* → **+** → *Apple Development*.
  - **Developer ID Application** — for builds you distribute. Same dialog → **+** → *Developer ID
    Application* (the account holder must create it), or create it at
    [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
    using a CSR from Keychain Access (*Certificate Assistant → Request a Certificate From a Certificate
    Authority…*).
- Check what you have:

  ```bash
  security find-identity -v -p codesigning
  ```

  You should see lines such as `"Apple Development: <name> (<id>)"` and
  `"Developer ID Application: <name or company> (<TEAM_ID>)"`.
- Your **Team ID** (10 characters): shown in parentheses in the Developer ID identity above, or under
  *Membership details* on developer.apple.com.

## 1. Local signed build (`make install`)

The project uses **automatic signing**: Xcode picks an Apple Development certificate for the team set in
the target's *Signing & Capabilities*. When you fork the project, use your own team:

- **Xcode:** open `Butler.xcodeproj` → target *Butler* → *Signing & Capabilities* → set *Team*, or
- **Command line:** pass your Team ID to the Makefile targets, which forwards it as `DEVELOPMENT_TEAM`:

  ```bash
  make release DEVELOPMENT_TEAM=ABCDE12345   # signed Release build in ./DerivedData/Build/Products/Release/Butler.app
  make install DEVELOPMENT_TEAM=ABCDE12345   # same, then replaces /Applications/Butler.app (old copy → Trash)
  ```

  Without `DEVELOPMENT_TEAM=` the team stored in the project file is used.

`make install` quits a running ButlerAI, moves the previous `/Applications/Butler.app` to the Trash,
copies the new build in with `ditto` (preserving the signature) and prints the installed version.
Launch it from `/Applications`; on first launch macOS shows the Accessibility prompt — click *Open
System Settings* and switch **Butler** on. Because the signature is certificate-based, later
`make install` runs keep the permission.

If you also change the **bundle identifier** (`PRODUCT_BUNDLE_IDENTIFIER`), do it before granting
permissions: TCC rows, the sandbox container (`~/Library/Containers/<bundle id>`) and the log file
location are all keyed by it.

> `make test` deliberately builds with code signing **disabled** so it runs on machines without
> certificates. The resulting ad-hoc test host shares the bundle identifier, which is why the app never
> touches the Accessibility API when running as a test host (`DeniedAccessibilityPermissionChecker`).

## 2. Developer ID release build (manual)

This is what the CI does; run it by hand when you need a distributable build locally.

1. **Configure export options.** Edit `ExportOptions.plist` and set your values:

   ```xml
   <key>method</key>             <string>developer-id</string>
   <key>teamID</key>             <string>YOUR_TEAM_ID</string>
   <key>signingStyle</key>       <string>manual</string>
   <key>signingCertificate</key> <string>Developer ID Application: Your Name or Company</string>
   ```

   `signingCertificate` must match the certificate's common name exactly as printed by
   `security find-identity` (without the `(TEAM_ID)` suffix).

2. **Archive** with the Developer ID identity:

   ```bash
   xcodebuild -project Butler.xcodeproj -scheme Butler -configuration Release \
     -archivePath build/Butler.xcarchive archive \
     DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
     CODE_SIGN_IDENTITY="Developer ID Application" \
     CODE_SIGN_STYLE=Manual
   ```

3. **Export** the signed app from the archive:

   ```bash
   xcodebuild -exportArchive \
     -archivePath build/Butler.xcarchive \
     -exportPath build/export \
     -exportOptionsPlist ExportOptions.plist
   ```

   The app is now at `build/export/Butler.app`, signed with hardened runtime and the entitlements from
   `Butler/Butler.entitlements`.

4. **Package** it as a DMG:

   ```bash
   hdiutil create -volname "ButlerAI" -srcfolder build/export/Butler.app -ov -format UDZO build/ButlerAI.dmg
   ```

5. **Notarize and staple.** Store your credentials once (uses an
   [app-specific password](https://support.apple.com/en-us/102654), never your Apple ID password):

   ```bash
   xcrun notarytool store-credentials "butler-notary" \
     --apple-id "you@example.com" --team-id "YOUR_TEAM_ID" --password "xxxx-xxxx-xxxx-xxxx"
   xcrun notarytool submit build/ButlerAI.dmg --keychain-profile "butler-notary" --wait
   xcrun stapler staple build/ButlerAI.dmg
   ```

   If notarization fails, fetch the report with
   `xcrun notarytool log <submission-id> --keychain-profile "butler-notary"`.

6. **Verify** before publishing (see [Verifying a signature](#verifying-a-signature)):

   ```bash
   spctl --assess --type open --context context:primary-signature -v build/ButlerAI.dmg
   ```

## 3. Automated release (GitHub Actions)

`.github/workflows/release.yml` performs steps 2–5 on every pushed tag matching `v*`, and attaches the
notarized DMG to a GitHub release. It needs these repository **secrets** (Settings → Secrets and
variables → Actions):

| Secret | Value | How to obtain it |
| --- | --- | --- |
| `CERTIFICATE_BASE64` | Developer ID Application certificate + private key as base64 `.p12` | Keychain Access → *My Certificates* → right-click the *Developer ID Application* certificate → *Export…* → format `.p12`, choose a password. Then `base64 -i Certificates.p12 \| pbcopy`. |
| `CERTIFICATE_PASSWORD` | The password chosen during the `.p12` export | — |
| `APPLE_DEVELOPER_ID` | The Apple ID (email) used for notarization | — |
| `APPLE_DEVELOPER_PASSWORD` | An **app-specific password** for that Apple ID | [account.apple.com](https://account.apple.com) → *Sign-In and Security* → *App-Specific Passwords*. |
| `TEAM_ID` | Your 10-character Team ID | developer.apple.com → *Membership details*. |

Also update `ExportOptions.plist` (`teamID`, `signingCertificate`) to match your certificate — the
export step reads it from the repository.

Cut a release with:

```bash
git tag v1.2.0
git push origin v1.2.0
```

## Entitlements explained

`Butler/Butler.entitlements` (applied to every signed build):

| Entitlement | Why |
| --- | --- |
| `com.apple.security.app-sandbox` | The app runs sandboxed. |
| `com.apple.security.network.client` | Calls the OpenAI API / a local Ollama server. |
| `com.apple.security.network.server` | Historical; kept for compatibility with existing installs. |
| `com.apple.security.files.user-selected.read-only` | Standard sandbox file access. |
| `com.apple.security.automation.apple-events` + temporary exception for `com.apple.systemevents` | Apple Events automation. |
| `com.apple.security.temporary-exception.mach-lookup.global-name` → `com.apple.coreservices.launchservicesd` | Launch Services lookups from the sandbox. |
| `com.apple.security.temporary-exception.mach-lookup.global-name` → `com.apple.universalaccessAuthWarn` | Lets the sandboxed app **show the Accessibility permission prompt** (see above). |

`ENABLE_HARDENED_RUNTIME = YES` is set in the project; it is required for notarization.

## Verifying a signature

```bash
codesign -dv --verbose=2 /Applications/Butler.app       # identity, team, hardened runtime flags
codesign --verify --deep --strict /Applications/Butler.app && echo OK
codesign -d --entitlements :- /Applications/Butler.app | plutil -p -   # entitlements actually embedded
codesign -d -r- /Applications/Butler.app                # designated requirement (what TCC binds to)
spctl --assess --type execute -v /Applications/Butler.app   # Gatekeeper verdict: "accepted" only for notarized Developer ID builds
```

A development-signed local build is expected to be `rejected` by `spctl` — Gatekeeper only vets
downloaded (quarantined) apps, so this does not affect running it locally.

## Troubleshooting

**"No signing certificate … found" / `errSecInternalComponent`** — run `security find-identity -v -p codesigning`;
if the identity is missing, create it (Prerequisites). If it is listed but signing still fails in a
script, the keychain is locked: `security unlock-keychain ~/Library/Keychains/login.keychain-db`.

**The shortcut stops working after rebuilding or re-signing** — the Accessibility row is bound to the old
signature. Reset it and let the app prompt again:

```bash
tccutil reset Accessibility uk.co.effectivecode.Butler   # use your bundle id if you changed it
open -a /Applications/Butler.app
```

Then enable *Butler* in System Settings → Privacy & Security → Accessibility. The menubar menu also
offers *Grant Access in System Settings…* and *Permission Help…* while access is missing.

**No prompt appears and the app is not listed under Accessibility** — the build lacks the
`com.apple.universalaccessAuthWarn` exception (check with `codesign -d --entitlements :-`), or you
launched an ad-hoc build. Either add the app manually with **+** (or drag it from Finder into the
list) or rebuild with the project's entitlements.

**Several rows for the app, or a row that is "on" but has no effect** — each differently-signed binary
(release, local dev build, test host) creates its own row for the same bundle id; only the one matching
the running binary counts. `tccutil reset Accessibility <bundle id>` removes them all; relaunch the app
you actually use and enable that row.

**Diagnosing** — the app writes its log to
`~/Library/Containers/uk.co.effectivecode.Butler/Data/Library/Logs/ButlerAI.log` (also visible in
*Show Logs* in the menubar menu). TCC's own decisions are in the unified log:
`/usr/bin/log show --last 5m --info --debug --predicate 'process == "tccd"' | grep -i butler`
(use the full path in case a shell alias shadows `log`).
