import CryptoKit
import Foundation
import OpenDictateCore

/// Audio of dictations that did not reach the clipboard, kept for "Send
/// again". It stays in the app's own container, is excluded from backups and
/// expires by the Mac's rule (`RecordingRetention`), checked whenever it is read.
/// As on the Mac, only recordings with a valid HMAC tag (key in the Keychain)
/// are offered for a retry, and the retry uploads exactly the bytes it checked.
struct PendingRecordings: Sendable {
    /// Finished recordings waiting for a successful send.
    let keptDirectory: URL
    /// The recording in progress. Anything left here at launch was cut off by
    /// the end of the process or could not be moved; it moves to `Kept`
    /// without a tag, so no audio is deleted unsent and none is sent unchecked.
    let activeDirectory: URL

    /// `base` is the app's Application Support folder; tests pass their own.
    init(base: URL? = nil) {
        let base =
            base
            ?? (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        keptDirectory = base.appendingPathComponent("Recordings/Kept", isDirectory: true)
        activeDirectory = base.appendingPathComponent("Recordings/Active", isDirectory: true)
    }

    /// Creates both folders and keeps what an earlier process left in
    /// `Active`. Call only while nothing records.
    func prepare() {
        let manager = FileManager.default
        for directory in [keptDirectory, activeDirectory] {
            try? manager.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        for leftover in (try? manager.contentsOfDirectory(at: activeDirectory, includingPropertiesForKeys: nil)) ?? [] {
            _ = keep(leftover, retryable: false)
        }
    }

    func newRecordingURL() -> URL {
        activeDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    /// Moves a recording into the kept folder, tags a finished one and returns
    /// where the audio now is. If the move fails, the original stays where it
    /// was; without a tag the audio is kept but not offered for a retry.
    func keep(_ url: URL, retryable: Bool = true) -> URL {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = keptDirectory.appendingPathComponent("\(stamp)-\(url.lastPathComponent)")
        do {
            try FileManager.default.moveItem(at: url, to: target)
        } catch {
            return url
        }
        if retryable, let key = KeychainStore.recordingKey(create: true),
            let audio = try? Data(contentsOf: target)
        {
            let tag = Data(HMAC<SHA256>.authenticationCode(for: audio, using: key))
            try? tag.write(to: Self.tagURL(for: target), options: .withoutOverwriting)
        }
        return target
    }

    /// The audio bytes when their tag is valid, else nil.
    func authenticatedAudio(at url: URL) -> Data? {
        guard let key = KeychainStore.recordingKey(create: false), let audio = try? Data(contentsOf: url),
            let tag = try? Data(contentsOf: Self.tagURL(for: url)),
            HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: audio, using: key)
        else { return nil }
        return audio
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: Self.tagURL(for: url))
    }

    /// Deletes expired recordings, then returns the newest one with a valid
    /// tag, leaving out `excluded`. An entry that fails the check or is left
    /// out never hides an older valid one.
    func newest(now: Date = Date(), excluding excluded: URL? = nil) -> RecordingRetention.Entry? {
        let entries = self.entries()
        let expired = RecordingRetention.expired(from: entries, now: now)
        for entry in expired { remove(entry.url) }
        // By name: the listed URLs need not equal the ones `keep` returned.
        var candidates = entries.filter {
            !expired.contains($0) && $0.url.lastPathComponent != excluded?.lastPathComponent
        }
        while let entry = RecordingRetention.newest(in: candidates) {
            if authenticatedAudio(at: entry.url) != nil { return entry }
            candidates.removeAll { $0 == entry }
        }
        return nil
    }

    private static func tagURL(for audio: URL) -> URL {
        audio.appendingPathExtension("tag")
    }

    private func entries() -> [RecordingRetention.Entry] {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: keptDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)) ?? []
        return files.filter { $0.pathExtension == "m4a" }.map { url in
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return RecordingRetention.Entry(url: url, created: created)
        }
    }
}
