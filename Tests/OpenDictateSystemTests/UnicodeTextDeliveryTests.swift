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
        #expect(!sent)
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
        #expect(!unfocused)
        #expect(attempts == 0)
        let failed = await UnicodeTextDelivery.send(
            String(repeating: "x", count: 45), stillFocused: { true },
            post: { _ in
                attempts += 1
                return false
            })
        #expect(!failed)
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
        #expect(await task.value == false)
        #expect(posted == 1)
    }
}
