import Foundation
import Testing
@testable import OpenDictateCore

@Suite("Trim planning")
struct TrimPlannerTests {
    private let padding: TimeInterval = 0.25
    private let minimum: TimeInterval = 1.0

    private func plan(
        original: TimeInterval,
        speech: (TimeInterval, TimeInterval)
    ) throws -> TrimPlan {
        try TrimPlanner.plan(
            originalDuration: original,
            speechRange: SpeechRange(start: speech.0, end: speech.1),
            padding: padding,
            minimumDuration: minimum
        )
    }

    @Test("Speech in the middle gets padded on both sides")
    func padsBothSides() throws {
        let result = try plan(original: 10, speech: (3, 7))
        #expect(result.start == 2.75)
        #expect(abs(result.uploadDuration - 4.5) < 0.0001)
        #expect(abs(result.trimmedDuration - 5.5) < 0.0001)
        #expect(result.shouldExport)
    }

    @Test("Speech starting before the padding never produces a negative offset")
    func neverNegativeStart() throws {
        let result = try plan(original: 10, speech: (0.1, 8))
        #expect(result.start == 0)
        #expect(result.uploadDuration > 0)
    }

    @Test("Speech running to the very end is clamped to the recording length")
    func clampsToEnd() throws {
        let result = try plan(original: 5, speech: (1, 5))
        #expect(result.start == 0.75)
        #expect(result.uploadDuration <= 5)
        #expect(abs(result.uploadDuration - 4.25) < 0.0001)
    }

    @Test("A recording shorter than the padding still yields a sane, non-negative plan")
    func shorterThanPadding() {
        // 0.2 s of audio, 0.25 s of padding on each side: the clamped span is the
        // whole file, which is under the 1 s minimum, so this must be rejected
        // rather than produce a negative or nonsense duration.
        #expect(throws: OpenDictateError.self) {
            _ = try plan(original: 0.2, speech: (0.05, 0.15))
        }
    }

    @Test("Too little left after trimming is rejected as too short")
    func rejectsTooShort() {
        #expect(throws: OpenDictateError.self) {
            _ = try plan(original: 30, speech: (10, 10.2))
        }
    }

    @Test("A saving under 0.35 s is not worth a re-encode")
    func skipsPointlessExport() throws {
        // Speech covers nearly everything: padding pushes the span to the full file.
        let result = try plan(original: 10, speech: (0.1, 9.9))
        #expect(!result.shouldExport)
        #expect(result.start == 0)
        #expect(result.uploadDuration == 10)
        #expect(result.trimmedDuration == 0)
    }

    @Test("Rejection carries the actual and required duration")
    func errorCarriesDurations() {
        do {
            _ = try plan(original: 30, speech: (10, 10.2))
            Issue.record("expected the plan to be rejected")
        } catch let error as OpenDictateError {
            guard case .recordingTooShort(let actual, let required) = error else {
                Issue.record("expected recordingTooShort, got \(error)")
                return
            }
            #expect(abs(actual - 0.7) < 0.0001)
            #expect(required == 1.0)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }
}
