import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class RecordingCoordinator: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var snapshot: RecordingSnapshot?
    @Published private(set) var message = "Mikrofon aus. Keine Übertragung."
    @Published private(set) var awaitingPermission = false

    private var recorder: AVAudioRecorder?
    private var audioURL: URL?
    private var stopTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    private var bridge: RecordingBridge? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: RecordingSnapshot.groupIdentifier)
            .map { RecordingBridge(directory: $0.appendingPathComponent("recording-coupling-v1")) }
    }

    var canStart: Bool { recorder == nil && !awaitingPermission && bridge != nil }
    var isRecording: Bool { recorder != nil }
    var hasAppGroup: Bool { bridge != nil }

    override init() {
        super.init()
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    if name == AVAudioSession.interruptionNotification,
                        (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                            != AVAudioSession.InterruptionType.began.rawValue
                    {
                        return
                    }
                    Task { @MainActor in
                        guard let self, self.recorder != nil else { return }
                        self.finish(success: false)
                    }
                })
        }
    }

    func start() {
        guard canStart, UIApplication.shared.applicationState == .active else { return }
        awaitingPermission = true
        let response: @Sendable (Bool) -> Void = { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.awaitingPermission = false
                guard granted else {
                    self.message = "Mikrofonzugriff abgelehnt. Keine Aufnahme gestartet."
                    return
                }
                guard self.canStart, UIApplication.shared.applicationState == .active else {
                    self.message = "Zum Start OpenDictate im Vordergrund öffnen."
                    return
                }
                self.beginRecording()
            }
        }
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: response)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(response)
        }
    }

    func stop() {
        guard recorder != nil else { return }
        finish(success: true)
    }

    func cancel() {
        guard recorder != nil else { return }
        finish(success: false)
    }

    private func beginRecording() {
        guard let bridge else { return }
        let id = UUID()
        let now = Date()
        let pending = RecordingSnapshot(id: id, startedAt: now, updatedAt: now, phase: .failed)
        snapshot = pending
        audioURL = nil
        do {
            try bridge.publish(pending, at: now)
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RecordingCouplingTests")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.completeUnlessOpen])
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            guard files.filter({ $0.pathExtension == "wav" }).count < 3 else {
                message = "Testgrenze erreicht: drei eigene Aufnahmedateien."
                return
            }
            let url = directory.appendingPathComponent("\(id.uuidString).wav")
            audioURL = url
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            let recorder = try AVAudioRecorder(
                url: url,
                settings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false
                ])
            self.recorder = recorder
            recorder.delegate = self
            guard recorder.prepareToRecord() else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600, .protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: url.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var excludedURL = url
            try excludedURL.setResourceValues(values)
            guard recorder.record(forDuration: RecordingSnapshot.recordingLimit) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let started = Date()
            let snapshot = RecordingSnapshot(id: id, startedAt: started, updatedAt: started, phase: .recording)
            self.snapshot = snapshot
            try bridge.publish(snapshot, at: started)
            message = "Aufnahme läuft. Jetzt manuell zu Safari wechseln und dort stoppen. Maximal 15 Sekunden."
            stopTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let snapshot = self.snapshot, self.recorder != nil else { return }
                    if self.bridge?.hasStopRequest(id: snapshot.id) == true { self.stop() }
                }
            }
        } catch {
            finish(success: false)
            message += " Start nicht abgeschlossen; vorhandene Testdateien bleiben erhalten."
        }
    }

    private func finish(success: Bool) {
        stopTimer?.invalidate()
        stopTimer = nil
        recorder?.delegate = nil
        recorder?.stop()
        self.recorder = nil
        let sessionMessage: String
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionMessage = "Aufnahme beendet."
        } catch {
            sessionMessage = "Aufnahme beendet; Audio-Sitzung konnte nicht deaktiviert werden."
        }

        guard var snapshot else {
            message = "\(sessionMessage) Vorhandene Testdatei bleibt erhalten."
            return
        }
        let now = Date()
        let duration: TimeInterval? = audioURL.flatMap { url in
            guard let file = try? AVAudioFile(forReading: url) else { return nil }
            return Double(file.length) / file.processingFormat.sampleRate
        }
        snapshot.updatedAt = now
        snapshot.phase = success && (duration.map { $0 > 0 && $0 <= 15.1 } ?? false) ? .ready : .failed
        snapshot.duration = snapshot.phase == .ready ? duration : nil
        self.snapshot = snapshot
        do {
            guard let bridge else { throw CocoaError(.fileWriteUnknown) }
            try bridge.publish(snapshot, at: now)
            message =
                snapshot.phase == .ready
                ? "\(sessionMessage) In der Tastatur lässt sich jetzt bewusst Testtext einfügen. Audio bleibt lokal."
                : "\(sessionMessage) Sitzung abgebrochen oder unterbrochen; Testaudio bleibt lokal erhalten."
        } catch {
            message = "\(sessionMessage) Übergabe nicht verfügbar; Testaudio bleibt lokal erhalten."
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, self.recorder.map(ObjectIdentifier.init) == identity else { return }
            self.finish(success: flag)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, self.recorder.map(ObjectIdentifier.init) == identity else { return }
            self.finish(success: false)
        }
    }
}
