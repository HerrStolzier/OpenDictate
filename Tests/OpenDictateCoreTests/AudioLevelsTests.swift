import Foundation
import Testing
@testable import OpenDictateCore

@Suite("Audio levels")
struct AudioLevelsTests {
    @Test("An empty window reports the floor instead of dividing by zero")
    func emptyWindow() {
        #expect(AudioLevels.decibels(sumSquares: 0, count: 0) == AudioLevels.floorDb)
    }

    @Test("Digital silence is clamped, never minus infinity")
    func digitalSilence() {
        let db = AudioLevels.decibels(sumSquares: 0, count: 1200)
        #expect(db.isFinite)
        #expect(abs(db - (-140)) < 0.001)
    }

    @Test("A quiet window lands below the app's silence threshold")
    func quietWindow() {
        // rms 0.001 -> -60 dB, well under the -45 dB threshold the app uses.
        let count = 1000
        let sumSquares = Float(count) * (0.001 * 0.001)
        let db = AudioLevels.decibels(sumSquares: sumSquares, count: count)
        #expect(abs(db - (-60)) < 0.01)
        #expect(db < -45)
    }

    @Test("A full-scale window is 0 dBFS and clears the threshold")
    func loudWindow() {
        let count = 1000
        let db = AudioLevels.decibels(sumSquares: Float(count), count: count)
        #expect(abs(db) < 0.01)
        #expect(db > -45)
    }
}

@Suite("Speech range detection")
struct SpeechRangeAccumulatorTests {
    private func accumulator(threshold: Float = -45) -> SpeechRangeAccumulator {
        SpeechRangeAccumulator(thresholdDb: threshold)
    }

    @Test("Silence throughout yields no range")
    func allSilent() {
        var acc = accumulator()
        for index in 0..<10 {
            acc.add(start: Double(index) * 0.05, end: Double(index + 1) * 0.05, db: -80)
        }
        #expect(acc.range == nil)
    }

    @Test("The range spans the first to the last loud window")
    func spansFirstToLast() {
        var acc = accumulator()
        acc.add(start: 0.00, end: 0.05, db: -80)
        acc.add(start: 0.05, end: 0.10, db: -20)
        acc.add(start: 0.10, end: 0.15, db: -80)
        acc.add(start: 0.15, end: 0.20, db: -30)
        acc.add(start: 0.20, end: 0.25, db: -90)
        #expect(acc.range == SpeechRange(start: 0.05, end: 0.20))
    }

    @Test("A window exactly on the threshold counts as speech")
    func thresholdIsInclusive() {
        var acc = accumulator(threshold: -45)
        acc.add(start: 1.0, end: 1.05, db: -45)
        #expect(acc.range == SpeechRange(start: 1.0, end: 1.05))
    }

    @Test("A single loud window produces a range, not nil")
    func singleWindow() {
        var acc = accumulator()
        acc.add(start: 2.0, end: 2.05, db: -10)
        #expect(acc.range == SpeechRange(start: 2.0, end: 2.05))
    }
}
