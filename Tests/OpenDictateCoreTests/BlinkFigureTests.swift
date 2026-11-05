import Foundation
import Testing

@testable import OpenDictateCore

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
