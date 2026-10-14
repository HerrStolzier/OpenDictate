import AppKit
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Indicator and daily menu")
@MainActor
struct DictationIndicatorSystemTests {
    init() { _ = NSApplication.shared }

    @Test func windowReportsEveryFlowStateWithItsReason() {
        let panel = DictationPanel()
        defer { panel.close() }
        var seen: [(IndicatorPhase, String)] = []
        panel.onDisplayChange = { display, detail in seen.append((IndicatorPhase(display), detail)) }
        panel.update(state: .recording)
        panel.update(state: .processing)
        panel.update(state: .delivering)
        panel.update(outcome: .deliveryUnconfirmed, transcript: "Hallo")
        panel.update(state: .idle)
        #expect(seen.map(\.0) == [.listening, .writing, .writing, .inserted])

        seen = []
        panel.update(state: .recording)
        panel.update(state: .processing)
        panel.setStatus("Keine Verbindung. Deine Aufnahme ist gesichert.")
        panel.update(outcome: .failed, transcript: nil)
        #expect(seen.last?.0 == .oops)
        #expect(seen.last?.1 == "Keine Verbindung. Deine Aufnahme ist gesichert.")
        #expect(panel.window?.isVisible == false)
    }

    /// Needs a screen: the indicator shows nothing without one. On a Mac this
    /// briefly orders a real window above the menu bar.
    @Test(.enabled(if: !NSScreen.screens.isEmpty)) func indicatorNeverTakesFocusOrActivatesTheApp() {
        let indicator = DictationIndicator()
        let keyWindow = NSApp.keyWindow
        let active = NSApp.isActive
        for display in [DictationDisplay.recording, .processing, .unconfirmed, .manual, .failure] {
            indicator.follow(display, detail: "Keine Verbindung.")
            indicator.updateRecording(elapsed: 3)
            #expect(NSApp.keyWindow === keyWindow)
            #expect(NSApp.isActive == active)
            let shown = NSApp.windows.filter { $0.level == .statusBar && $0.isVisible }
            // Successful endings may stay hidden over a full-screen app.
            if IndicatorPhase(display).needsAttention { #expect(!shown.isEmpty, "\(display)") }
            for window in shown {
                #expect(!window.canBecomeKey)
                #expect(!window.canBecomeMain)
                #expect(window.collectionBehavior.contains(.canJoinAllSpaces))
            }
        }
        indicator.dismiss()
        #expect(indicator.phase == .closed)
    }

    @Test func dailyMenuListsTheAgreedItemsInOrder() throws {
        let delegate = MenuDelegateStub()
        let controller = MenuBarController(delegate: delegate)
        controller.menuNeedsUpdate(controller.dailyMenu)
        let items = controller.dailyMenu.items
        // Values such as the shortcut follow a tab on the right.
        func label(_ item: NSMenuItem) -> String { item.title.components(separatedBy: "\t")[0] }
        #expect(items.first?.view != nil)
        #expect(
            items.dropFirst().map { $0.isSeparatorItem ? "—" : label($0) } == [
                "—", "Diktat starten", "Letzten Text ansehen", "Gesicherte Aufnahmen", "—", "Automatisch einfügen",
                "Übersetzen: Aus", "—", "Einstellungen …", "Hilfe", "—", "OpenDictate beenden"
            ])
        let settings = try #require(items.first { $0.title == "Einstellungen …" })
        #expect(settings.keyEquivalent == "," && settings.keyEquivalentModifierMask == .command)
        let quit = try #require(items.first { $0.title == "OpenDictate beenden" })
        #expect(quit.keyEquivalent == "q" && quit.action == #selector(NSApplication.terminate(_:)))
        #expect(items.first { $0.title == "Automatisch einfügen" }?.state == .on)
        #expect(items.first { $0.title == "Letzten Text ansehen" }?.isEnabled == false)

        delegate.state = .recording
        delegate.needsSetup = true
        controller.menuNeedsUpdate(controller.dailyMenu)
        let titles = controller.dailyMenu.items.map(label)
        #expect(titles.contains("API-Schlüssel einrichten …"))
        #expect(titles.contains("Diktat beenden"))
        delegate.state = .processing
        controller.menuNeedsUpdate(controller.dailyMenu)
        #expect(controller.dailyMenu.items.map(label).contains("Abbrechen (Aufnahme bleibt)"))
    }

    @Test func dailyMenuShowsWhoWritesOnceAServerIsSetUp() throws {
        let delegate = MenuDelegateStub()
        delegate.service = .server
        delegate.serverHost = "127.0.0.1"
        let controller = MenuBarController(delegate: delegate)
        controller.menuNeedsUpdate(controller.dailyMenu)
        let service = try #require(controller.dailyMenu.items.first { $0.title.hasPrefix("Dienst:") })
        #expect(service.title == "Dienst: Eigener Server")
        let choices = try #require(service.submenu?.items)
        #expect(choices.map(\.title) == ["OpenAI", "Eigener Server (127.0.0.1)"])
        #expect(choices.map(\.state) == [.off, .on])
        #expect(choices.allSatisfy { $0.isEnabled })

        let openAI = try #require(choices.first)
        let action = try #require(openAI.action)
        NSApp.sendAction(action, to: openAI.target, from: openAI)
        #expect(delegate.selectedServices == [.openAI])

        // While a dictation runs, the choice waits; the next one uses it.
        delegate.state = .processing
        controller.menuNeedsUpdate(controller.dailyMenu)
        let busy = try #require(controller.dailyMenu.items.first { $0.title.hasPrefix("Dienst:") })
        #expect(busy.submenu?.items.allSatisfy { !$0.isEnabled } == true)
    }
}

@MainActor
private final class MenuDelegateStub: MenuBarControllerDelegate {
    var state = DictationState.idle
    var needsSetup = false
    var service = Settings.Service.openAI
    var serverHost: String?
    var selectedServices: [Settings.Service] = []

    func menuBarDidConfigureShortcut() {}
    func menuBarDidConfigureVocabulary() {}
    func menuBarDidConfigureCustomServer() {}
    func menuBarDidCancel(discard: Bool) {}
    func menuBarDidCopyLastText() {}
    func menuBarDidClearLastText() {}
    func menuBarDidToggleAutoPaste() {}
    var menuBarRecordings: [SavedRecording] { [] }
    func menuBarDidRetry(filename: String) {}
    func menuBarDidDelete(filename: String) {}
    var menuBarState: DictationState { state }
    var menuBarHasTranscript: Bool { false }
    var menuBarAutoPaste: Bool { true }
    var menuBarNeedsAPIKeySetup: Bool { needsSetup }
    func menuBarDidTriggerToggleRecording() {}
    func menuBarDidTriggerRetry() {}
    func menuBarDidTriggerDeleteSavedRecordings() {}
    func menuBarDidTriggerSetAPIKey() {}
    func menuBarDidSelect(trigger: RecordingTrigger) {}
    func menuBarDidSelect(model: TranscriptionModel) {}
    func menuBarDidSelect(service: Settings.Service) { selectedServices.append(service) }
    func menuBarDidSelect(language: String?) {}
    func menuBarDidSelect(translationTarget: String?) {}
    func menuBarDidSelect(indicatorStyle: IndicatorStyle) {}
    func menuBarDidShowLastText() {}
    var menuBarIndicatorStyle: IndicatorStyle { .menuBar }
    var menuBarStateWord: String { "Bereit" }
    var menuBarTrigger: RecordingTrigger { .default }
    var menuBarModel: TranscriptionModel { .default }
    var menuBarService: Settings.Service { service }
    var menuBarServerHost: String? { serverHost }
    var menuBarLanguage: String? { nil }
    var menuBarTranslationTarget: String? { nil }
}
