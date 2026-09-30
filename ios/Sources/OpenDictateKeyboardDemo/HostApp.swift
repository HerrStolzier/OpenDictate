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
    @StateObject private var recording = RecordingCoordinator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("OpenDictate Kopplungstest")
                    .font(.largeTitle.bold())

                Text("Aufnahme und Tastatur prüfen")
                    .font(.headline)

                Text(
                    "Aufnahme hier starten, manuell zur Ziel-App wechseln, dort in OpenDictate stoppen. Danach lässt sich markierter Testtext bewusst einfügen. Noch keine Transkription."
                )

                Divider()

                Text("Tastatur aktivieren")
                    .font(.headline)

                Text(
                    "Einstellungen → Allgemein → Tastatur → Tastaturen → Neue Tastatur hinzufügen → OpenDictate Tastaturtest."
                )

                Text(
                    "Für Stopp und Übergabe ist „Vollen Zugriff erlauben“ nötig. Normale Tasten und der bisherige Testknopf funktionieren weiterhin ohne diesen Zugriff."
                )

                if !recording.hasAppGroup {
                    Text(
                        "Die gemeinsame App-Gruppe ist noch nicht für diesen Kandidaten eingerichtet. Aufnahme gesperrt."
                    )
                    .foregroundStyle(.secondary)
                }

                Text(recording.message)
                    .accessibilityIdentifier("recording.status")

                Button("Aufnahme starten · maximal 15 Sekunden") { recording.start() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!recording.canStart)
                    .accessibilityIdentifier("recording.start")

                if recording.isRecording {
                    Button("Aufnahme stoppen") { recording.stop() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("recording.stop")
                    Button("Abbrechen · Audio behalten") { recording.cancel() }
                        .accessibilityIdentifier("recording.cancel")
                }

                Divider()

                Text("Prüfung in Safari")
                    .font(.headline)

                Text(
                    "Die Hauptaufgabe öffnet die lokale Testseite. Tippe dort in ein leeres Feld und wähle die OpenDictate-Tastatur. Folge dem Prüfplan."
                )

                Text(
                    "Nur lokaler Machbarkeitsnachweis. Höchstens drei Aufnahmedateien, kein Anbieter oder Netzwerk. Testaudio wird nicht automatisch gelöscht."
                )
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("prototype.instructions")
    }
}
