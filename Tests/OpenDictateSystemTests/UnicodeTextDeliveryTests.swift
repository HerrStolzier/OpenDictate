import AppKit
import Testing

@testable import OpenDictate

@Suite("Exact browser text delivery without posting events")
@MainActor
struct UnicodeTextDeliveryTests {
    @Test func chunksPreserveUnicodeAndBoundaries() {
        let text =
            String(repeating: "a", count: 19) + "🍏grüne Äpfel.\ne\u{301} 👩🏽‍💻" + String(repeating: " Ende.", count: 20)
        let chunks = UnicodeTextDelivery.chunks(text)
        #expect(chunks.allSatisfy { !$0.isEmpty && $0.count <= 20 })
        #expect(chunks.map { String(decoding: $0, as: UTF16.self) }.joined() == text)
        #expect(UnicodeTextDelivery.chunks("").isEmpty)
    }

    @Test func eventsCarryExactTextAndNoModifiers() throws {
        let units = Array("grüne Äpfel 🍏".utf16)
        let (down, up) = try #require(UnicodeTextDelivery.events(units))
        #expect(down.type == .keyDown)
        #expect(up.type == .keyUp)
        for event in [down, up] {
            #expect(event.flags.isEmpty)
            var length = 0
            var actual = [UniChar](repeating: 0, count: 40)
            event.keyboardGetUnicodeString(
                maxStringLength: actual.count, actualStringLength: &length, unicodeString: &actual)
            #expect(Array(actual.prefix(length)) == units)
        }
    }

    @Test func lineBreakCommandsNeverDiscardFollowingTextInTheSameEvent() {
        let text = String(repeating: "x", count: 20) + "\nFollowing text\r\n\nEnd 🍏"
        let chunks = UnicodeTextDelivery.chunks(text, lineBreakPolicy: .isolated)
        #expect(chunks.map { String(decoding: $0, as: UTF16.self) }.joined() == text)
        #expect(chunks.contains([10]))
        #expect(chunks.contains([13, 10]))
        #expect(chunks.allSatisfy { !$0.contains(10) && !$0.contains(13) || $0.count == 1 || $0 == [13, 10] })
        #expect(UnicodeTextDelivery.chunks("Before\nAfter") == [Array("Before\nAfter".utf16)])
    }

    @Test func browserPoliciesPreserveLongTextWithoutChangingGroupedEditors() {
        let sample = "Äpfel 🍏 und Grüße.\nZweite Zeile: e\u{301}, 👩🏽‍💻."
        let text = Array(repeating: sample, count: 600).joined(separator: " ")
        let safari = UnicodeTextDelivery.chunks(text, lineBreakPolicy: .isolated)
        #expect(safari.map { String(decoding: $0, as: UTF16.self) }.joined() == text)
        #expect(safari.count == 2_400)
        #expect(safari.allSatisfy { !$0.contains(10) || $0 == [10] })

        let brave = UnicodeTextDelivery.chunks(text, lineBreakPolicy: .trailing)
        #expect(brave.map { String(decoding: $0, as: UTF16.self) }.joined() == text)
        #expect(brave.allSatisfy { !$0.isEmpty && $0.count <= 20 })
        #expect(brave.dropFirst().allSatisfy { $0.first != 10 && $0.first != 13 })
        #expect(UnicodeTextDelivery.policy(for: "com.apple.Safari") == .isolated)
        #expect(UnicodeTextDelivery.policy(for: "com.brave.Browser") == .trailing)
        #expect(UnicodeTextDelivery.policy(for: "md.obsidian") == .grouped)
        #expect(UnicodeTextDelivery.policy(for: nil) == .grouped)
    }

    @Test func trailingPolicyKeepsCRLFAndBlankLinesBehindText() {
        let text = "Erste\r\n\r\nZweite\n\nDritte"
        let chunks = UnicodeTextDelivery.chunks(text, lineBreakPolicy: .trailing)
        #expect(chunks.map { String(decoding: $0, as: UTF16.self) }.joined() == text)
        #expect(chunks.allSatisfy { $0.first != 10 && $0.first != 13 })
        #expect(chunks.allSatisfy { $0.count <= 20 })
    }

    @Test func trailingPolicyRejectsUnsafeInputBeforePosting() async {
        let longGrapheme = "a" + String(repeating: "\u{301}", count: 20)
        #expect(UnicodeTextDelivery.chunks("\nLeading", lineBreakPolicy: .trailing).isEmpty)
        #expect(UnicodeTextDelivery.chunks(longGrapheme, lineBreakPolicy: .trailing).isEmpty)

        var posts = 0
        let sent = await UnicodeTextDelivery.send(
            "\nLeading", lineBreakPolicy: .trailing, stillFocused: { true },
            post: { _ in
                posts += 1
                return true
            })
        #expect(sent == .notAttempted)
        #expect(posts == 0)
    }

    @Test func targetSwitchStopsRemainingText() async {
        var focused = true
        var posted: [[UniChar]] = []
        let sent = await UnicodeTextDelivery.send(
            String(repeating: "x", count: 45), stillFocused: { focused },
            post: {
                posted.append($0)
                focused = false
                return true
            })
        #expect(sent == .interrupted)
        #expect(posted.count == 1)
    }

    @Test func unfocusedOrFailedTargetNeverContinues() async {
        var attempts = 0
        let unfocused = await UnicodeTextDelivery.send(
            "Text", stillFocused: { false },
            post: { _ in
                attempts += 1
                return true
            })
        #expect(unfocused == .notAttempted)
        #expect(attempts == 0)
        let failed = await UnicodeTextDelivery.send(
            String(repeating: "x", count: 45), stillFocused: { true },
            post: { _ in
                attempts += 1
                return false
            })
        #expect(failed == .notAttempted)
        #expect(attempts == 1)
    }

    @Test func cancellationPreventsFurtherEvents() async {
        var posted = 0
        let task = Task { @MainActor in
            await UnicodeTextDelivery.send(
                String(repeating: "x", count: 45), stillFocused: { true },
                post: { _ in
                    posted += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return true
                })
        }
        #expect(await task.value == .interrupted)
        #expect(posted == 1)
    }

    @Test func postingFailureAfterFirstChunkPreservesEvidenceOfEarlierSubmission() async {
        var attempts = 0
        var posted: [[UniChar]] = []
        let result = await UnicodeTextDelivery.send(
            String(repeating: "x", count: 45), stillFocused: { true },
            post: {
                attempts += 1
                guard attempts == 1 else { return false }
                posted.append($0)
                return true
            })
        #expect(result == .interrupted)
        #expect(attempts == 2)
        #expect(posted.count == 1)
    }

    @Test func cancellationBeforeFirstChunkSubmitsNothing() async {
        var posted = 0
        let task = Task { @MainActor in
            await UnicodeTextDelivery.send(
                String(repeating: "x", count: 45), stillFocused: { true },
                post: { _ in
                    posted += 1
                    return true
                })
        }
        task.cancel()
        #expect(await task.value == .notAttempted)
        #expect(posted == 0)
    }

    @Test func completeSubmissionPreservesEveryChunkWithoutConfirmingInsertion() async {
        let text = String(repeating: "Grüße 🍏! ", count: 8)
        var posted: [[UniChar]] = []
        let result = await UnicodeTextDelivery.send(
            text, stillFocused: { true },
            post: {
                posted.append($0)
                return true
            })
        #expect(result == .submitted)
        #expect(posted == UnicodeTextDelivery.chunks(text))
        #expect(String(decoding: posted.flatMap { $0 }, as: UTF16.self) == text)
    }

    @Test func cancellationAfterFinalChunkCannotUndoCompleteSubmission() async {
        let text = String(repeating: "x", count: 45)
        let chunks = UnicodeTextDelivery.chunks(text)
        var posted: [[UniChar]] = []
        let task = Task { @MainActor in
            await UnicodeTextDelivery.send(
                text, stillFocused: { true },
                post: {
                    posted.append($0)
                    if posted.count == chunks.count { withUnsafeCurrentTask { $0?.cancel() } }
                    return true
                })
        }
        #expect(await task.value == .submitted)
        #expect(posted == chunks)
    }
}
