import SwiftUI

/// Settings section that shows whether ButlerAI has Accessibility access and lets the user fix it.
struct AccessibilityPermissionView: View {
    @ObservedObject var service: AccessibilityPermissionService
    var shortcut: KeyboardShortcutSpec = HotkeyManager.improveTextShortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow

            Text(service.statusDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !service.isGranted {
                howToSteps
            }

            actionButtons

            footnote
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: service.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(service.isGranted ? Color.green : Color.orange)
                .imageScale(.large)
            Text(service.statusTitle)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(service.statusTitle)
        .accessibilityAddTraits(.isStaticText)
    }

    private var howToSteps: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("1. Open System Settings")
            Text("2. Go to Privacy & Security › Accessibility")
            Text("3. Turn on ButlerAI")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("How to enable: open System Settings, go to Privacy and Security, Accessibility, then turn on ButlerAI.")
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if service.isGranted {
                Button("Open System Settings") {
                    service.openSystemSettings()
                }
                .accessibilityHint("Opens the Accessibility pane of System Settings.")
            } else {
                Button("Open System Settings") {
                    service.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens the Accessibility pane of System Settings so you can turn on ButlerAI.")

                Button("Request Access") {
                    service.requestAccess()
                }
                .accessibilityHint("Asks macOS to show the Accessibility permission prompt.")
            }

            Button("Check Again") {
                service.refresh()
            }
            .accessibilityHint("Re-checks whether Accessibility access has been granted.")
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Required for the \(shortcut.displayString) shortcut and for replacing the selected text.")
            if let lastCheckedAt = service.lastCheckedAt {
                Text("Last checked \(lastCheckedAt, style: .relative) ago")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}

/// Compact warning for the menu bar menu; renders nothing while access is granted.
/// Kept to plain `Label` + `Button` children so SwiftUI can flatten it into menu items.
struct AccessibilityStatusBanner: View {
    @ObservedObject var service: AccessibilityPermissionService
    var onOpenSettings: () -> Void

    var body: some View {
        if !service.isGranted {
            Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.orange)
                .accessibilityLabel("Accessibility access required")

            Button("Fix Accessibility Access…", action: onOpenSettings)
                .accessibilityHint("Opens ButlerAI settings to grant Accessibility access.")
        }
    }
}

#if DEBUG
private struct PreviewAccessibilityChecker: AccessibilityPermissionChecking {
    let trusted: Bool
    func isTrusted() -> Bool { trusted }
    @discardableResult func promptForTrust() -> Bool { trusted }
    func openSystemSettings() {}
}

#Preview("Not granted") {
    AccessibilityPermissionView(service: AccessibilityPermissionService(checker: PreviewAccessibilityChecker(trusted: false)))
        .padding()
        .frame(width: 400)
}

#Preview("Granted") {
    AccessibilityPermissionView(service: AccessibilityPermissionService(checker: PreviewAccessibilityChecker(trusted: true)))
        .padding()
        .frame(width: 400)
}

#Preview("Banner") {
    AccessibilityStatusBanner(service: AccessibilityPermissionService(checker: PreviewAccessibilityChecker(trusted: false))) {}
        .frame(width: 260)
}
#endif
