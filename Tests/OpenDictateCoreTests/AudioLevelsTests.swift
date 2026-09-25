import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Speech range detection")
struct SpeechRangeAccumulatorTests {
    private func accumulator(threshold: Float = -45) -> SpeechRangeAccumulator {
        SpeechRangeAccumulator(thresholdDb: threshold)
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

}
