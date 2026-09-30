import SwiftUI

@main
struct OpenDictateKeyboardDemoApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeInstructionsView()
        }
    }
}

private struct PrototypeInstructionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("OpenDictate Tastaturtest")
                    .font(.largeTitle.bold())

                Text("Nur ein Textpfad-Prototyp")
                    .font(.headline)

                Text(
                    "Die Tastatur fügt nach bewusstem Tastendruck vorbereiteten synthetischen Testtext in das aktuelle Textfeld ein."
                )

                Divider()

                Text("Tastatur aktivieren")
                    .font(.headline)

                Text(
                    "Einstellungen → Allgemein → Tastatur → Tastaturen → Neue Tastatur hinzufügen → OpenDictate Tastaturtest."
                )

                Text("„Allow Full Access“ ausgeschaltet lassen. Der Prototyp benötigt es nicht.")

                Divider()

                Text("Prüfung in Safari")
                    .font(.headline)

                Text(
                    "Die Hauptaufgabe öffnet die lokale Fixture unter 127.0.0.1. Folge für Feldwechsel und Passwortfeld dem Prüfplan."
                )

                Text("Keine Aufnahme, kein Mikrofon, kein Provider und kein Netzwerkzugriff.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("prototype.instructions")
    }
}
