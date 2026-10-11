import AVFAudio
import ActivityKit
import AppIntents
import OpenDictateCore
import SwiftUI

/// The start screen: Blink with the state word, the last result, "Send again"
/// and the few steps that make dictation work without opening the app.
struct ContentView: View {
    @State private var showsSettings = false
    @State private var microphone = Recorder.permission
    @State private var hasKey = KeychainStore.apiKey() != nil
    @State private var activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @AppStorage(AppSettings.serverAddressKey) private var serverAddress = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var runner: DictationRunner { .shared }
    private var theme: DesignTheme { .matching(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignMetric.space6) {
                    state
                    controls
                    if let text = runner.lastText { result(text) }
                    setup
                }
                .padding(.horizontal, DesignMetric.space4)
                .padding(.bottom, DesignMetric.space8)
            }
            .background(Color(design: .bg, theme: theme))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.pick("Settings", "Einstellungen"))
                }
            }
            .sheet(isPresented: $showsSettings, onDismiss: refresh) { SettingsView() }
        }
        .tint(Color(design: .signal, theme: theme))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .task { await runner.reachServer() }
    }

    // MARK: State

    private var indicator: IndicatorPhase {
        switch runner.phase {
        case .ready: .closed
        case .listening: .listening
        case .writing: .writing
        case .copied: .copied
        case .oops: .oops
        }
    }

    private var word: String {
        switch runner.phase {
        case .ready: L10n.ready
        case .listening: L10n.word(.listening)
        case .writing: L10n.word(.writing)
        case .copied: L10n.word(.copied)
        case .oops: L10n.word(.oops)
        }
    }

    private var state: some View {
        VStack(spacing: DesignMetric.space3) {
            BlinkView(pose: indicator.pose, theme: theme)
                .frame(height: 176)
                .padding(.top, DesignMetric.space6)
            Text(word)
                .font(BrandFont.pixel(40))
                .foregroundStyle(Color(design: indicator == .oops ? .warn : .ink, theme: theme))
                .accessibilityAddTraits(.updatesFrequently)
            detail
                .font(BrandFont.sans(16))
                .foregroundStyle(Color(design: .inkMuted, theme: theme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var detail: some View {
        switch runner.phase {
        case .ready:
            Text(
                DeviceTrigger.hasActionButton
                    ? L10n.pick("Press the Action button to start.", "Drücke die Aktionstaste, um zu starten.")
                    : L10n.pick(
                        "Double-tap the back of your iPhone to start.",
                        "Tippe zweimal auf die Rückseite deines iPhones, um zu starten."))
        case .listening(let since):
            TimelineView(.periodic(from: since, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(since)
                let left = IndicatorText.remaining(elapsed: elapsed, limit: DictationRunner.limit)
                Text(left <= 10 ? L10n.stopsIn(left) : "REC " + IndicatorText.clock(elapsed))
                    .font(BrandFont.mono(16))
                    .monospacedDigit()
            }
        case .writing:
            Text(L10n.pick("Turning your words into text …", "Deine Worte werden zu Text …"))
        case .copied:
            Text(L10n.copiedDetail)
        case .oops(let message):
            Text(message)
        }
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        VStack(spacing: DesignMetric.space3) {
            switch runner.phase {
            case .listening:
                Button(L10n.stop) { Task { try? await runner.finish() } }
                    .buttonStyle(PixelButtonStyle(primary: true, theme: theme))
            case .writing:
                Button(L10n.word(.writing)) {}
                    .buttonStyle(PixelButtonStyle(primary: true, theme: theme))
                    .disabled(true)
            case .ready, .copied, .oops:
                Button(L10n.pick("Start dictation", "Diktat starten")) { Task { try? await runner.start() } }
                    .buttonStyle(PixelButtonStyle(primary: true, theme: theme))
            }
            if let entry = runner.retryable, !runner.isBusy {
                Button(L10n.pick("Send again", "Nochmal senden")) { Task { await runner.retry() } }
                    .buttonStyle(PixelButtonStyle(primary: false, theme: theme))
                    .accessibilityHint(
                        Text(
                            L10n.pick("Recorded at ", "Aufgenommen um ")
                                + entry.created.formatted(date: .omitted, time: .shortened)))
            }
        }
    }

    private func result(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DesignMetric.space3) {
            Text(L10n.pick("Last text", "Letzter Text"))
                .font(BrandFont.mono(13, semibold: true, relativeTo: .caption))
                .foregroundStyle(Color(design: .inkMuted, theme: theme))
            Text(text)
                .font(BrandFont.sans(17))
                .foregroundStyle(Color(design: .ink, theme: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.pick("Copy again", "Nochmal kopieren")) { runner.copyAgain() }
                .font(BrandFont.mono(15, semibold: true))
                .disabled(runner.isBusy)
        }
        .padding(DesignMetric.space4)
        .background(
            RoundedRectangle(cornerRadius: DesignMetric.radiusCard).fill(Color(design: .surface, theme: theme)))
    }

    // MARK: Setup

    private var needsKey: Bool { !hasKey && !(AppSettings.endpoint?.isLoopback ?? false) }

    private var setup: some View {
        VStack(alignment: .leading, spacing: DesignMetric.space4) {
            Text(L10n.pick("Set up", "Einrichten"))
                .font(BrandFont.mono(13, semibold: true, relativeTo: .caption))
                .foregroundStyle(Color(design: .inkMuted, theme: theme))
            step(done: microphone == .granted, L10n.pick("Microphone", "Mikrofon")) {
                switch microphone {
                case .granted:
                    EmptyView()
                case .denied:
                    Button(L10n.pick("Allow in Settings", "In Einstellungen erlauben"), action: openSettings)
                default:
                    Button(L10n.pick("Allow microphone", "Mikrofon erlauben")) {
                        Task {
                            _ = await Recorder.requestPermission()
                            refresh()
                        }
                    }
                }
            }
            if !activitiesEnabled {
                step(done: false, L10n.pick("Live Activities", "Live-Aktivitäten")) {
                    Text(
                        L10n.pick(
                            "iOS stops a background recording without them.",
                            "Ohne sie beendet iOS eine Aufnahme im Hintergrund."))
                    Button(L10n.pick("Turn on in Settings", "In Einstellungen einschalten"), action: openSettings)
                }
            }
            step(done: !needsKey, L10n.pick("OpenAI API key", "OpenAI-API-Schlüssel")) {
                if needsKey {
                    Button(L10n.pick("Add API key", "API-Schlüssel hinterlegen")) { showsSettings = true }
                }
            }
            step(done: false, L10n.pick("Start without opening the app", "Starten, ohne die App zu öffnen")) {
                Text(
                    L10n.pick(
                        "1. Add “Dictate” to your shortcuts in the Shortcuts app.",
                        "1. Lege in der Kurzbefehle-App den Kurzbefehl „Diktieren“ an."))
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                Text(
                    DeviceTrigger.hasActionButton
                        ? L10n.pick(
                            "2. Settings → Action Button → Shortcut → “Dictate”.",
                            "2. Einstellungen → Aktionstaste → Kurzbefehl → „Diktieren“.")
                        : L10n.pick(
                            "2. Settings → Accessibility → Touch → Back Tap → Double Tap → “Dictate”.",
                            "2. Einstellungen → Bedienungshilfen → Tippen → Auf Rückseite tippen → "
                                + "Doppeltippen → „Diktieren“."))
                Text(
                    L10n.pick(
                        "3. Run it again to stop. The text is then on the clipboard; paste it anywhere.",
                        "3. Nochmal auslösen beendet das Diktat. Der Text liegt dann in der Zwischenablage."))
            }
        }
        .font(BrandFont.sans(15))
        .foregroundStyle(Color(design: .ink, theme: theme))
        .padding(DesignMetric.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignMetric.radiusCard).fill(Color(design: .surface, theme: theme)))
    }

    private func step(done: Bool, _ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignMetric.space2) {
            Label {
                Text(title).font(BrandFont.sans(16, semibold: true))
            } icon: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color(design: done ? .signal : .inkMuted, theme: theme))
            }
            .accessibilityValue(done ? L10n.pick("Done", "Erledigt") : L10n.pick("Open", "Offen"))
            content()
        }
    }

    private func refresh() {
        microphone = Recorder.permission
        hasKey = KeychainStore.apiKey() != nil
        activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        runner.refreshRetryable()
        Task { await runner.reachServer() }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// The design system's button on a stepped plate.
struct PixelButtonStyle: ButtonStyle {
    let primary: Bool
    let theme: DesignTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandFont.mono(16, semibold: true))
            .foregroundStyle(Color(design: primary ? .onSignal : .ink, theme: theme))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(PixelPlate().fill(Color(design: primary ? .signal : .line, theme: theme)))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .contentShape(PixelPlate())
    }
}

enum DeviceTrigger {
    /// The iPhone 15 Pro and later have the Action button (model identifier
    /// `iPhone16,1` and up); the iPhone 15 and older start with "Back Tap".
    static let hasActionButton: Bool = {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        guard model.hasPrefix("iPhone"), let major = Int(model.dropFirst(6).prefix { $0.isNumber }) else {
            return false
        }
        return major >= 16
    }()
}
