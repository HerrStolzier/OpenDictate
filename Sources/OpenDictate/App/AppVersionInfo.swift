import Foundation

/// Identifies the running bundle, never the source checkout beside it.
struct AppVersionInfo {
    let version: String
    let build: String
    let sourceRevision: String?
    let sourceState: String

    var versionDescription: String { "Version \(version) · Build \(build)" }
    var sourceDescription: String {
        let revision = sourceRevision.map { String($0.prefix(12)) } ?? "unbekannt"
        return "Quellrevision: \(revision) (\(sourceState))"
    }
    var summary: String { "\(versionDescription); \(sourceDescription)" }

    init(bundle: Bundle = .main) {
        func value(_ key: String) -> String? {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        version = value("CFBundleShortVersionString") ?? "unbekannt"
        build = value("CFBundleVersion") ?? "unbekannt"
        let revision = value("OpenDictateSourceRevision")
        if let revision, revision.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil {
            sourceRevision = revision
        } else {
            sourceRevision = nil
        }
        switch (sourceRevision != nil, value("OpenDictateSourceState")) {
        case (true, "clean"): sourceState = "ohne lokale Änderungen"
        case (true, "dirty"): sourceState = "Basis mit lokalen Änderungen"
        case (true, "unverified"): sourceState = "nicht verifiziert"
        case (_, "unversioned"): sourceState = "ohne Git-Zuordnung"
        default: sourceState = "Quellstatus unbekannt"
        }
    }
}
