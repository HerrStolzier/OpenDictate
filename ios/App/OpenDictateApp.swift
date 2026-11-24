import SwiftUI

@main
struct OpenDictateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // System parts such as the settings sheet match the Nacht theme.
                .preferredColorScheme(.dark)
                // The keyboard's dictation key opens the app when no session runs.
                .onOpenURL { url in
                    guard KeyboardLink.isStartSession(url) else { return }
                    Task { try? await KeyboardDictation.shared.startSession() }
                }
        }
    }
}
