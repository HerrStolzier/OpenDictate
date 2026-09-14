import Foundation
import OpenDictateCore

/// UserDefaults documents thread-safe access, including on SDKs that do not
/// declare its Sendable conformance. Keep that compatibility promise local.
final class UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults

    init(_ defaults: UserDefaults) { self.defaults = defaults }

    func object(forKey defaultName: String) -> Any? { defaults.object(forKey: defaultName) }
    func set(_ value: Any?, forKey defaultName: String) { defaults.set(value, forKey: defaultName) }
    func removeObject(forKey defaultName: String) { defaults.removeObject(forKey: defaultName) }
}
