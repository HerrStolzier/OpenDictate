import SwiftUI

@main
struct OpenDictateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // System parts such as the settings sheet match the Nacht theme.
                .preferredColorScheme(.dark)
        }
    }
}
