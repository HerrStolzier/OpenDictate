import OpenDictateCore
import SwiftUI

/// Starts and ends "Keep microphone warm" for the OpenDictate keyboard and
/// explains the one-time setup in iOS Settings.
struct KeyboardCard: View {
    let theme: DesignTheme

    private var keyboard: KeyboardDictation { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignMetric.space3) {
            Text(L10n.pick("Keyboard", "Tastatur"))
                .font(BrandFont.mono(13, semibold: true, relativeTo: .caption))
                .foregroundStyle(Color(design: .inkMuted, theme: theme))
            Text(state)
                .font(BrandFont.sans(16, semibold: true))
                .foregroundStyle(Color(design: .ink, theme: theme))
                .accessibilityIdentifier("keyboardState")
            if let problem = keyboard.problem {
                Text(problem)
                    .font(BrandFont.sans(15))
                    .foregroundStyle(Color(design: .warn, theme: theme))
            }
            if keyboard.phase == .off {
                Button(L10n.pick("Keep microphone warm", "Mikro warm halten")) {
                    Task { try? await keyboard.startSession() }
                }
                .buttonStyle(PixelButtonStyle(primary: false, theme: theme))
                .accessibilityIdentifier("startWarm")
            } else {
                Button(L10n.pick("Turn microphone off", "Mikro ausschalten")) { keyboard.endSession() }
                    .buttonStyle(PixelButtonStyle(primary: false, theme: theme))
                    .accessibilityIdentifier("endWarm")
            }
            Text(
                L10n.pick(
                    "Once: Settings → General → Keyboard → Keyboards → Add New Keyboard → OpenDictate, "
                        + "then tap OpenDictate and allow Full Access. Typing works without it.",
                    "Einmalig: Einstellungen → Allgemein → Tastatur → Tastaturen → Tastatur hinzufügen → "
                        + "OpenDictate, dann OpenDictate antippen und „Vollen Zugriff“ erlauben. "
                        + "Tippen geht auch ohne.")
            )
            .font(BrandFont.sans(15))
            .foregroundStyle(Color(design: .inkMuted, theme: theme))
        }
        .padding(DesignMetric.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignMetric.radiusCard).fill(Color(design: .surface, theme: theme)))
    }

    private var state: String {
        switch keyboard.phase {
        case .off: return L10n.pick("Microphone off", "Mikro aus")
        case .ready:
            guard let until = keyboard.warmUntil else { return L10n.pick("Microphone warm", "Mikro warm") }
            let time = until.formatted(date: .omitted, time: .shortened)
            return L10n.pick("Microphone warm until \(time)", "Mikro warm bis \(time)")
        case .recording: return L10n.word(.listening)
        case .writing: return L10n.word(.writing)
        }
    }
}
