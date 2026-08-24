import AppKit

/// Central place for the app's modal alerts so call sites stay small and consistent.
@MainActor
enum AlertPresenter {
    /// Shows a modal alert and returns the chosen button (`.alertFirstButtonReturn` for the first title).
    @discardableResult
    static func show(
        title: String,
        message: String,
        style: NSAlert.Style = .warning,
        buttons: [String] = ["OK"]
    ) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        for button in buttons {
            alert.addButton(withTitle: button)
        }
        NSApp.activate()
        return alert.runModal()
    }

    /// Shows an alert offering to open Settings; returns `true` when the user chose to open them.
    static func confirmOpenSettings(title: String, message: String) -> Bool {
        show(title: title, message: message, buttons: ["Open Settings", "Cancel"]) == .alertFirstButtonReturn
    }
}
