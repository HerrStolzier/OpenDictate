import CryptoKit
import Darwin
import Foundation
import OpenDictateCore

/// Keeps recordings whose transcription failed. Only recordings authenticated
/// with a device-local Keychain key are eligible for retry or automatic pruning.
enum FailedRecordingStore {
    struct RetryPayload: Sendable {
        let url: URL
        let data: Data
    }

    private static let maximumAudioBytes = 16 * 1_024 * 1_024
    private static let authenticationBytes = 32

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/OpenDictate/failed", isDirectory: true)
    }

    /// Copies the temporary audio into the protected recovery store. The caller
    /// still owns and cleans up the original temporary artifact.
    @discardableResult
    static func keep(_ audioURL: URL, recordedAt: Date) -> URL? {
        keep(audioURL, recordedAt: recordedAt, in: directory, key: RecordingAuthenticationKeyStore.readOrCreate)
    }

    /// Explicit storage and key provider keep filesystem checks isolated from
    /// the user's recovery directory and Keychain.
    static func keep(
        _ audioURL: URL, recordedAt: Date, in directoryURL: URL, key: () throws -> SymmetricKey
    ) -> URL? {
        do {
            guard let audioData = secureRead(audioURL, maximumBytes: maximumAudioBytes),
                !audioData.isEmpty
            else {
                throw CocoaError(.fileReadTooLarge)
            }
            let key = try key()
            try prepareDirectory(directoryURL)

            let filename = "\(timestamp(recordedAt))-\(UUID().uuidString.prefix(8)).m4a"
            let destination = directoryURL.appendingPathComponent(filename, isDirectory: false)
            let authenticator = authenticationCode(for: audioData, filename: filename, key: key)

            do {
                try audioData.write(to: destination, options: .withoutOverwriting)
                guard hardenRegularFilePermissions(destination) else { throw CocoaError(.fileWriteUnknown) }
                let authURL = authenticationURL(for: destination)
                try authenticator.write(to: authURL, options: .withoutOverwriting)
                guard hardenRegularFilePermissions(authURL) else { throw CocoaError(.fileWriteUnknown) }
            } catch {
                _ = unlinkFile(destination)
                _ = unlinkFile(authenticationURL(for: destination))
                throw error
            }

            AppLog.write("Kept an authenticated failed recording at \(destination.path)")
            prune(now: Date(), in: directoryURL)
            return destination
        } catch {
            AppLog.write("Could not keep the failed recording: \(error.localizedDescription)")
            return nil
        }
    }

    /// Loads and authenticates bytes once. The caller uploads these exact bytes,
    /// avoiding a second path lookup after validation.
    static func newest(now: Date = Date()) -> RetryPayload? {
        guard let key = RecordingAuthenticationKeyStore.read() else { return nil }
        return newest(now: now, in: directory, key: key)
    }

    static func newest(now: Date, in directoryURL: URL, key: SymmetricKey) -> RetryPayload? {
        for url in candidateAudioURLs(in: directoryURL).sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
            if let payload = payload(at: url, now: now, key: key) { return payload }
        }
        return nil
    }

    static func payload(filename: String, now: Date = Date()) -> RetryPayload? {
        guard isExpectedFilename(filename), let key = RecordingAuthenticationKeyStore.read() else { return nil }
        return payload(at: directory.appendingPathComponent(filename), now: now, key: key)
    }

    static func payload(at url: URL, now: Date, key: SymmetricKey) -> RetryPayload? {
        guard let created = date(from: url.lastPathComponent),
            now.timeIntervalSince(created) < RecordingRetention.maximumAge,
            let audioData = secureRead(url, maximumBytes: maximumAudioBytes),
            let savedCode = secureRead(authenticationURL(for: url), maximumBytes: authenticationBytes),
            savedCode.count == authenticationBytes,
            isValidAuthenticationCode(savedCode, for: audioData, filename: url.lastPathComponent, key: key)
        else { return nil }
        return RetryPayload(url: url, data: audioData)
    }

    static var storedFileCount: Int { candidateAudioURLs().count }

    @discardableResult
    static func remove(_ payload: RetryPayload) -> Bool {
        removeAudioAndAuthentication(at: payload.url)
    }

    /// User-requested cleanup also removes legacy files from versions that did
    /// not authenticate recordings. Unknown names and directories are untouched.
    @discardableResult
    static func removeAll() -> Int {
        var removed = 0
        for url in candidateAudioURLs() {
            if removeAudioAndAuthentication(at: url) {
                removed += 1
            } else {
                AppLog.write("Could not delete saved recording \(url.lastPathComponent): errno=\(errno)")
            }
        }
        return removed
    }

    @discardableResult
    static func prune(now: Date = Date()) -> Int {
        prune(now: now, in: directory)
    }

    @discardableResult
    static func prune(now: Date, in directoryURL: URL) -> Int {
        do {
            try prepareDirectory(directoryURL)
        } catch {
            AppLog.write("Could not secure the failed-recording directory: \(error.localizedDescription)")
            return 0
        }

        let audioURLs = candidateAudioURLs(in: directoryURL)
        hardenPermissions(for: audioURLs)
        let entries = audioURLs.compactMap { url in
            date(from: url.lastPathComponent).map { RecordingRetention.Entry(url: url, created: $0) }
        }
        let expired = RecordingRetention.expired(from: entries, now: now)
        var removed = 0
        for entry in expired {
            if removeAudioAndAuthentication(at: entry.url) {
                removed += 1
            } else {
                AppLog.write("Could not prune expired failed recording \(entry.url.lastPathComponent): errno=\(errno)")
            }
        }
        pruneOrphanAuthenticationFiles(in: directoryURL)
        if removed > 0 {
            AppLog.write("Pruned \(removed) expired failed recording(s)")
        }
        return removed
    }

    static func candidateAudioURLs(in directoryURL: URL? = nil) -> [URL] {
        let directoryURL = directoryURL ?? directory
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        return contents.filter { url in
            guard isExpectedFilename(url.lastPathComponent),
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            else { return false }
            return values.isRegularFile == true && values.isSymbolicLink != true
        }
    }

    static func secureRead(_ url: URL, maximumBytes: Int) -> Data? {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { return nil }
        defer { Darwin.close(descriptor) }

        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            metadata.st_mode & S_IFMT == S_IFREG,
            metadata.st_uid == geteuid(),
            metadata.st_size >= 0,
            metadata.st_size <= maximumBytes
        else { return nil }

        var data = Data(count: Int(metadata.st_size))
        let count = data.count
        let didReadAll = data.withUnsafeMutableBytes { buffer -> Bool in
            guard var address = buffer.baseAddress else { return count == 0 }
            var remaining = count
            while remaining > 0 {
                let bytesRead = Darwin.read(descriptor, address, remaining)
                if bytesRead < 0 && errno == EINTR { continue }
                guard bytesRead > 0 else { return false }
                address = address.advanced(by: bytesRead)
                remaining -= bytesRead
            }
            return true
        }
        return didReadAll ? data : nil
    }

    static func authenticationCode(for data: Data, filename: String, key: SymmetricKey) -> Data {
        Data(
            HMAC<SHA256>.authenticationCode(
                for: authenticatedMessage(audioData: data, filename: filename),
                using: key
            ))
    }

    static func isValidAuthenticationCode(
        _ code: Data,
        for data: Data,
        filename: String,
        key: SymmetricKey
    ) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(
            code,
            authenticating: authenticatedMessage(audioData: data, filename: filename),
            using: key
        )
    }

    private static func authenticatedMessage(audioData: Data, filename: String) -> Data {
        var message = Data(filename.utf8)
        message.append(0)
        message.append(audioData)
        return message
    }

    private static func prepareDirectory(_ directoryURL: URL? = nil) throws {
        let directoryURL = directoryURL ?? directory
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let descriptor = Darwin.open(directoryURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { Darwin.close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            metadata.st_mode & S_IFMT == S_IFDIR,
            metadata.st_uid == geteuid(),
            fchmod(descriptor, 0o700) == 0
        else { throw CocoaError(.fileWriteNoPermission) }
    }

    private static func hardenPermissions(for audioURLs: [URL]) {
        for audioURL in audioURLs {
            _ = hardenRegularFilePermissions(audioURL)
            let authURL = authenticationURL(for: audioURL)
            _ = hardenRegularFilePermissions(authURL)
        }
    }

    private static func hardenRegularFilePermissions(_ url: URL) -> Bool {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }
        var metadata = stat()
        return fstat(descriptor, &metadata) == 0
            && metadata.st_mode & S_IFMT == S_IFREG
            && metadata.st_uid == geteuid()
            && fchmod(descriptor, 0o600) == 0
    }

    private static func pruneOrphanAuthenticationFiles(in directoryURL: URL) {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        for authURL in contents where authURL.lastPathComponent.hasSuffix(".m4a.auth") {
            let audioName = String(authURL.lastPathComponent.dropLast(5))
            guard isExpectedFilename(audioName) else { continue }
            let audioURL = directoryURL.appendingPathComponent(audioName, isDirectory: false)
            // Only remove a sidecar when its audio directory entry is absent.
            // Reading the audio is unnecessary here; uncertain or unreadable
            // entries retain their sidecar. Retry still authenticates all bytes.
            var metadata = stat()
            if lstat(audioURL.path, &metadata) != 0 && errno == ENOENT {
                _ = unlinkFile(authURL)
            }
        }
    }

    /// `unlink` removes one directory entry and never follows a replacement
    /// symlink or recursively deletes a directory swapped in after validation.
    static func unlinkFile(_ url: URL) -> Bool {
        Darwin.unlink(url.path) == 0 || errno == ENOENT
    }

    /// Retain the authentication sidecar when macOS refuses to remove audio.
    /// Otherwise a protected recording could lose its only retry credential.
    @discardableResult
    static func removeAudioAndAuthentication(at audioURL: URL) -> Bool {
        guard unlinkFile(audioURL) else { return false }
        _ = unlinkFile(authenticationURL(for: audioURL))
        return true
    }

    private static func authenticationURL(for audioURL: URL) -> URL {
        audioURL.appendingPathExtension("auth")
    }

    static func isExpectedFilename(_ filename: String) -> Bool {
        filename.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z-[0-9A-F]{8}\.m4a$"#,
            options: .regularExpression
        ) != nil
    }

    static func date(from filename: String) -> Date? {
        guard filename.count >= 20 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return formatter.date(from: String(filename.prefix(20)))
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return formatter.string(from: date)
    }
}
