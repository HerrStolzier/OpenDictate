import Foundation
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Preparation and termination ordering")
@MainActor
struct AppLifecycleTests {
    @MainActor
    final class Deferred<Value: Sendable> {
        private var continuation: CheckedContinuation<Value, Never>?
        private var observer: CheckedContinuation<Void, Never>?

        func value() async -> Value {
            await withCheckedContinuation {
                continuation = $0
                observer?.resume()
                observer = nil
            }
        }

        func waitUntilRequested() async {
            if continuation != nil { return }
            await withCheckedContinuation { observer = $0 }
        }

        func resolve(_ value: Value) {
            let pending = continuation
            continuation = nil
            pending?.resume(returning: value)
        }
    }

    @MainActor
    final class Harness {
        let lifecycle = AppLifecycle()
        let upload = Deferred<String>()
        let original = URL(fileURLWithPath: "/test/lifecycle-original.m4a")
        var suspendUpload = false
        var starts = 0
        var stops = 0
        var uploads = 0
        var copied = 0
        var kept: [URL] = []
        var cleaned: [URL] = []
        var confirmations = 0
        var cancellations = 0
        var replies = 0
        var duringKeep: (() -> Void)?

        lazy var flow = DictationFlow(
            operations: .init(
                start: { self.starts += 1 },
                stop: {
                    self.stops += 1
                    return self.original
                },
                prepare: { _ in PreparedAudio(url: self.original, uploadDuration: 2) },
                transcribeFile: { _ in
                    self.uploads += 1
                    if self.suspendUpload { return await self.upload.value() }
                    return "Testtext"
                },
                transcribeRetry: { _ in
                    self.uploads += 1
                    return "Testtext"
                },
                keep: {
                    self.kept.append($0)
                    self.duringKeep?()
                    return true
                },
                removeRetry: { _ in },
                clean: { self.cleaned.append($0) },
                copy: { _ in
                    self.copied += 1
                    return true
                },
                paste: { _ in .notAttempted }
            ))

        func quit(confirm: () -> Bool) -> AppLifecycle.TerminationReply {
            lifecycle.requestTermination(
                hasActiveDictation: flow.state != .idle,
                confirm: {
                    self.confirmations += 1
                    return confirm()
                },
                cancel: {
                    self.cancellations += 1
                    self.flow.cancel()
                    return self.flow.task
                }, reply: { self.replies += 1 })
        }
    }

    @Test func preparationRemainsExclusiveAcrossBothKeyReads() throws {
        let h = Harness()
        let operation = try #require(h.lifecycle.beginOperation())
        defer { h.lifecycle.finish(operation) }
        var nestedAttempts = 0
        let keyRead = {
            nestedAttempts += 1
            #expect(h.lifecycle.beginOperation() == nil)
            #expect(h.flow.state == .idle)
        }
        keyRead()
        keyRead()
        #expect(try h.lifecycle.commit(operation) { _ = try h.flow.start() })
        #expect(nestedAttempts == 2 && h.starts == 1)
        h.flow.cancel()
    }

    @Test func lateMicrophoneAnswerCannotStartOrReleaseANewerPreparation() async throws {
        let h = Harness()
        let microphone = Deferred<Bool>()
        let old = try #require(h.lifecycle.beginOperation())
        let oldTask = Task { @MainActor in
            defer { h.lifecycle.finish(old) }
            if await microphone.value() {
                _ = try? h.lifecycle.commit(old) { _ = try h.flow.start() }
            }
        }
        await microphone.waitUntilRequested()
        h.lifecycle.cancelPreparation()
        let current = try #require(h.lifecycle.beginOperation())
        microphone.resolve(true)
        await oldTask.value
        #expect(h.starts == 0)
        #expect(h.lifecycle.isCurrent(current))
        #expect(h.lifecycle.beginOperation() == nil)
        #expect(try h.lifecycle.commit(current) { _ = try h.flow.start() })
        h.lifecycle.finish(current)
        h.flow.cancel()
    }

    @Test func backDuringRetryLoadingInvalidatesTheUpload() async throws {
        let h = Harness()
        let load = Deferred<Bool>()
        let operation = try #require(h.lifecycle.beginOperation())
        let task = Task { @MainActor in
            defer { h.lifecycle.finish(operation) }
            _ = await load.value()
            h.lifecycle.commit(operation) {
                _ = h.flow.retry(.init(url: h.original, data: Data([1])))
            }
        }
        await load.waitUntilRequested()
        h.lifecycle.cancelPreparation()
        load.resolve(true)
        await task.value
        #expect(h.uploads == 0 && h.flow.state == .idle)
        #expect(h.cleaned.isEmpty)
    }

    @Test func cancelBeforeQueuedPreparationRunsSkipsItsKeyReadAndUpload() async throws {
        let h = Harness()
        let operation = try #require(h.lifecycle.beginOperation())
        var keyReads = 0
        let task = Task { @MainActor in
            defer { h.lifecycle.finish(operation) }
            guard h.lifecycle.isCurrent(operation) else { return }
            keyReads += 1
            h.lifecycle.commit(operation) {
                _ = h.flow.retry(.init(url: h.original, data: Data([1])))
            }
        }
        h.lifecycle.cancelPreparation()
        await task.value
        #expect(keyReads == 0 && h.uploads == 0 && h.flow.state == .idle)
        #expect(h.lifecycle.canBeginOperation)
    }

    @Test func quitDuringPreparationRejectsLateSuccessAndErrorCallbacks() async throws {
        for permitted in [false, true] {
            let h = Harness()
            let microphone = Deferred<Bool>()
            let operation = try #require(h.lifecycle.beginOperation())
            var errors = 0
            let task = Task { @MainActor in
                defer { h.lifecycle.finish(operation) }
                let granted = await microphone.value()
                _ = try? h.lifecycle.commit(operation) {
                    if granted { _ = try h.flow.start() } else { errors += 1 }
                }
            }
            await microphone.waitUntilRequested()
            #expect(h.quit { true } == .now)
            microphone.resolve(permitted)
            await task.value
            #expect(!h.lifecycle.isCurrent(operation))
            #expect(h.lifecycle.beginOperation() == nil)
            #expect(h.confirmations == 0 && h.cancellations == 0 && h.replies == 0)
            #expect(errors == 0 && h.starts == 0)
        }
    }

    @Test func setupModalCannotAdmitAHotkeyOrSaveAfterNestedQuit() throws {
        let lifecycle = AppLifecycle()
        let setup = try #require(lifecycle.beginOperation())
        #expect(lifecycle.beginOperation() == nil)
        #expect(
            lifecycle.requestTermination(
                hasActiveDictation: false, confirm: { false }, cancel: { nil }, reply: {}) == .now)
        var saves = 0
        #expect(!lifecycle.commit(setup) { saves += 1 })
        lifecycle.finish(setup)
        #expect(saves == 0 && !lifecycle.canBeginOperation)
    }

    @Test func finishingFlowInsideQuitDialogDoesNotAllowASecondQuit() throws {
        let h = Harness()
        _ = try h.flow.start()
        #expect(
            h.quit {
                h.flow.cancel()
                #expect(h.flow.state == .idle)
                #expect(h.quit { true } == .cancel)
                #expect(h.lifecycle.beginOperation() == nil)
                return false
            } == .cancel)
        #expect(h.confirmations == 1 && h.cancellations == 0 && h.replies == 0)
        #expect(h.lifecycle.canBeginOperation)
    }

    @Test func automaticStopsWaitForTheQuitDecision() async throws {
        for confirmed in [false, true] {
            let h = Harness()
            _ = try h.flow.start()
            let result = h.quit {
                h.lifecycle.automaticStop { _ = h.flow.stop() }
                h.lifecycle.automaticStop { _ = h.flow.stop() }
                #expect(h.stops == 0 && h.uploads == 0)
                return confirmed
            }
            if confirmed {
                #expect(result == .later)
                await h.lifecycle.terminationTask?.value
                #expect(h.kept == [h.original] && h.uploads == 0 && h.replies == 1)
            } else {
                #expect(result == .cancel)
                await h.flow.task?.value
                #expect(h.kept.isEmpty && h.uploads == 1 && h.replies == 0)
                #expect(h.lifecycle.acceptsActions)
            }
            #expect(h.stops == 1)
        }
    }

    @Test func declinedQuitKeepsTheExistingUploadAlive() async throws {
        let h = Harness()
        h.suspendUpload = true
        _ = try h.flow.start()
        _ = h.flow.stop()
        let task = try #require(h.flow.task)
        await h.upload.waitUntilRequested()
        #expect(h.quit { false } == .cancel)
        #expect(!task.isCancelled && h.flow.state == .processing)
        h.upload.resolve("Erhaltenes Ergebnis")
        await task.value
        #expect(h.copied == 1 && h.kept.isEmpty)
        #expect(h.cancellations == 0 && h.replies == 0)
    }

    @Test func repeatedQuitDrainsOnceBeforeItsSingleReply() async throws {
        let h = Harness()
        h.suspendUpload = true
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.upload.waitUntilRequested()
        #expect(h.quit { true } == .later)
        #expect(h.quit { true } == .later)
        #expect(h.lifecycle.beginOperation() == nil)
        #expect(h.confirmations == 1 && h.cancellations == 1 && h.replies == 0)
        h.upload.resolve("Verspätetes Ergebnis")
        await h.lifecycle.terminationTask?.value
        #expect(h.kept == [h.original] && h.copied == 0 && h.replies == 1)
        h.lifecycle.automaticStop { _ = h.flow.stop() }
        #expect(h.stops == 1)
    }

    @Test func reentrantQuitDuringRecoveryCannotCancelOrReplyTwice() async throws {
        let h = Harness()
        h.duringKeep = {
            #expect(h.quit { true } == .later)
            #expect(h.lifecycle.beginOperation() == nil)
        }
        _ = try h.flow.start()
        #expect(h.quit { true } == .later)
        await h.lifecycle.terminationTask?.value
        #expect(h.confirmations == 1 && h.cancellations == 1 && h.replies == 1)
        #expect(h.kept == [h.original] && h.uploads == 0 && h.stops == 1)
    }

    @Test func normalCancellationFinishesRecoveryBeforeQuitCanProceed() throws {
        let h = Harness()
        var nestedQuits = 0
        h.duringKeep = {
            nestedQuits += 1
            #expect(h.flow.state == .processing && h.flow.task == nil)
            #expect(h.quit { true } == .cancel)
            #expect(h.lifecycle.beginOperation() == nil)
            h.lifecycle.cancelDictation { Issue.record("Cancellation was entered twice") }
        }
        _ = try h.flow.start()
        h.lifecycle.cancelDictation { h.flow.cancel() }
        #expect(nestedQuits == 1 && h.kept == [h.original] && h.stops == 1)
        #expect(h.flow.state == .idle && h.lifecycle.canBeginOperation)
        #expect(h.quit { true } == .now)
        #expect(h.confirmations == 0 && h.cancellations == 0 && h.replies == 0)
    }
}
