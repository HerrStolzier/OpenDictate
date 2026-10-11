import AppKit
import Foundation

/// Deep links into the System Settings panes the app tells users to visit.
@MainActor
enum SystemSettings {
    static func openAccessibility() {
        AppLog.write("Opening Accessibility settings")
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    /// Keyboard pane, where "Press 🌐 key to" lives.
    static func openKeyboard() {
        AppLog.write("Opening Keyboard settings")
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    static func openSound() {
        AppLog.write("Opening Sound settings")
        open("x-apple.systempreferences:com.apple.preference.sound")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }
}
