import CoreGraphics
import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Dictation indicator")
struct DictationIndicatorTests {
    @Test func everyWindowStateMapsToOneIndicatorWord() {
        let expected: [DictationDisplay: IndicatorPhase] = [
            .ready: .closed, .setup: .closed, .retry: .closed,
            .recording: .listening,
            .processing: .writing, .cancelling: .writing,
            .confirmed: .inserted, .unconfirmed: .inserted,
            .manual: .copied,
            .failure: .oops
        ]
        #expect(Set(expected.keys) == Set(DictationDisplay.allCases))
        for (display, phase) in expected { #expect(IndicatorPhase(display) == phase, "\(display)") }
        #expect(
            IndicatorPhase.allCases.map(\.word) == ["Bereit", "Hört zu", "Schreibt", "Eingefügt", "Kopiert", "Hoppla"])
    }

    @Test func onlySuccessfulEndingsCloseByThemselves() {
        #expect(IndicatorPhase.inserted.closesAfter == .seconds(2))
        #expect(IndicatorPhase.copied.closesAfter == .seconds(4))
        for phase in [IndicatorPhase.listening, .writing, .oops] {
            #expect(phase.closesAfter == nil)
            #expect(phase.needsAttention)
        }
    }

    @Test func linesUnderTheWordSayWhatHappens() {
        #expect(IndicatorContent(phase: .listening, elapsed: 3.9, limit: 90).detail == "REC 0:03")
        #expect(IndicatorContent(phase: .listening, elapsed: 75, limit: 90).detail == "REC 1:15")
        #expect(IndicatorContent(phase: .listening, elapsed: 80.2, limit: 90).detail == "REC · Stopp in 10 s")
        #expect(IndicatorContent(phase: .listening, elapsed: 89.5, limit: 90).detail == "REC · Stopp in 1 s")
        #expect(IndicatorContent(phase: .listening, elapsed: 95, limit: 90).detail == "REC · Stopp in 0 s")
        #expect(IndicatorContent(phase: .writing).detail == "OpenAI wandelt um")
        #expect(IndicatorContent(phase: .writing, translating: true).detail == "OpenAI übersetzt")
        #expect(IndicatorContent(phase: .inserted).detail == "per ⌘V, kurz prüfen")
        let copied = IndicatorContent(phase: .copied)
        #expect(copied.detail == "Nicht eingefügt. Der Text liegt in der Zwischenablage.")
        #expect(copied.compactDetail == "in der Zwischenablage")
        let oops = IndicatorContent(phase: .oops, reason: "Keine Verbindung. Deine Aufnahme ist gesichert.")
        #expect(oops.accessibilityLabel == "OpenDictate: Hoppla. Keine Verbindung. Deine Aufnahme ist gesichert.")
        #expect(oops.compactDetail.isEmpty)
    }

    @Test func countdownIsAnnouncedAtTenAndFiveSeconds() {
        #expect(IndicatorText.countdownMilestone(elapsed: 79, limit: 90) == nil)
        #expect(IndicatorText.countdownMilestone(elapsed: 80.5, limit: 90) == 10)
        #expect(IndicatorText.countdownMilestone(elapsed: 85.1, limit: 90) == 5)
    }

    @Test func screenWithoutNotchFollowsTheSetting() {
        let mini = IndicatorScreen(hasNotch: false, showsMenuBar: true)
        #expect(IndicatorStyle.default == .floating)
        #expect(IndicatorLayout.placement(for: .listening, on: mini, style: .menuBar) == .menuBar)
        #expect(IndicatorLayout.placement(for: .listening, on: mini, style: .floating) == .floating)
        #expect(IndicatorLayout.placement(for: .listening, on: mini, style: .off) == .statusItem)
        #expect(IndicatorLayout.placement(for: .inserted, on: mini, style: .menuBar) == .menuBar)
        #expect(IndicatorLayout.placement(for: .closed, on: mini, style: .menuBar) == .hidden)
        #expect(IndicatorLayout.statusItemTitle(for: .listening, placement: .statusItem, elapsed: 64) == "REC 1:04")
        #expect(IndicatorLayout.placement(for: .oops, on: mini, style: .off) == .floating)
        #expect(IndicatorLayout.statusItemTitle(for: .listening, placement: .menuBar, elapsed: 3) == nil)
    }

    @Test func notchGrowsOutOfTheNotchWhateverTheSetting() {
        let book = IndicatorScreen(hasNotch: true, showsMenuBar: true)
        for style in IndicatorStyle.allCases {
            #expect(IndicatorLayout.placement(for: .writing, on: book, style: style) == .notch)
            #expect(IndicatorLayout.placement(for: .copied, on: book, style: style) == .notch)
        }
        #expect(IndicatorLayout.statusItemTitle(for: .listening, placement: .notch, elapsed: 3) == "REC")
    }

    @Test func fullScreenShowsOnlyRecordingWritingAndErrors() {
        let game = IndicatorScreen(hasNotch: false, showsMenuBar: false)
        for phase in [IndicatorPhase.listening, .writing, .oops] {
            #expect(IndicatorLayout.placement(for: phase, on: game, style: .menuBar) == .floating)
            #expect(IndicatorLayout.placement(for: phase, on: game, style: .floating) == .floating)
            #expect(
                IndicatorLayout.placement(for: phase, on: game, style: .off) == (phase == .oops ? .floating : .hidden))
        }
        for phase in [IndicatorPhase.inserted, .copied] {
            #expect(IndicatorLayout.placement(for: phase, on: game, style: .menuBar) == .hidden)
        }
        let notchGame = IndicatorScreen(hasNotch: true, showsMenuBar: false)
        #expect(IndicatorLayout.placement(for: .listening, on: notchGame, style: .off) == .notch)
        #expect(IndicatorLayout.placement(for: .inserted, on: notchGame, style: .menuBar) == .hidden)
    }

    @Test func activeScreenIsWhereTheFrontmostAppsWindowIs() throws {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let external = CGRect(x: 1512, y: -200, width: 2560, height: 1440)
        let windows = [
            ScreenWindow(ownerPID: 9, layer: 25, bounds: CGRect(x: 700, y: 0, width: 30, height: 24)),
            ScreenWindow(ownerPID: 42, layer: 0, bounds: CGRect(x: 1600, y: -175, width: 1200, height: 800)),
            ScreenWindow(ownerPID: 7, layer: 0, bounds: main)
        ]
        let browser = try #require(
            IndicatorLayout.activeScreen(windows: windows, frontmostPID: 42, screens: [main, external]))
        #expect(browser.index == 1)
        #expect(!browser.coveredByWindow)
        let game = try #require(
            IndicatorLayout.activeScreen(windows: windows, frontmostPID: 7, screens: [main, external]))
        #expect(game.index == 0)
        #expect(game.coveredByWindow)
        #expect(IndicatorLayout.activeScreen(windows: windows, frontmostPID: 9, screens: [main, external]) == nil)
        #expect(IndicatorLayout.activeScreen(windows: windows, frontmostPID: nil, screens: [main, external]) == nil)
    }
}

@Suite("Blink figure")
struct BlinkFigureTests {
    @Test func motionMovesInStepsAndStandsStillWhenReduced() {
        #expect(BlinkMotion.body.frame(at: 0.2).opacity == 1)
        #expect(BlinkMotion.body.frame(at: 0.6).opacity == 0)
        #expect(BlinkMotion.body.frame(at: 0.6, animated: false).opacity == 1)
        #expect(BlinkMotion.runB.frame(at: 0.2, animated: false).opacity == 0)
        #expect(BlinkMotion.hop.frame(at: 0.6).dy == -5)
        #expect(BlinkMotion.hop.frame(at: 0.6, animated: false).dy == 0)
        #expect(BlinkMotion.arc.frame(at: 0.1, delay: 0.4).opacity == 1)
        #expect(BlinkMotion.type.frame(at: 0.1, delay: 0.3).opacity == 0)
        let arc = (0..<6).map { BlinkMotion.arc.frame(at: Double($0) * 0.2 + 0.01).opacity }
        #expect(arc.map { ($0 * 100).rounded() } == [20, 47, 73, 100, 73, 47])
    }

    @Test func smallFigureKeepsTheMenuBarFileAndLightsTheSolesOnlyWhenNeeded() throws {
        let cells = { (pose: BlinkPose) in BlinkFigure.small(pose).layers.flatMap(\.runs) }
        // design/assets/logos/blink-16.svg in Nacht colours.
        let svg = try String(
            contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("design/assets/logos/blink-16.svg"),
            encoding: .utf8)
        let rect = try Regex(##"x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)" fill="#([0-9A-F]{6})""##)
        let file = Set(
            svg.matches(of: rect).map { match in
                "\(match[1].substring!),\(match[2].substring!),\(match[3].substring!),\(match[4].substring!),"
                    + "\(match[5].substring!)"
            })
        #expect(file.count == 9)
        let drawn = Set(
            cells(.bereit).map { run in
                "\(run.x),\(run.y),\(run.width),\(run.height),"
                    + String(format: "%06X", run.color.0.rgb(in: .nacht))
            })
        #expect(drawn == file)
        for pose in BlinkPose.allCases {
            let rec = cells(pose).contains { $0.color.0 == .rec }
            #expect(rec == (pose == .hoert || pose == .hoppla), "\(pose)")
        }
    }
}
