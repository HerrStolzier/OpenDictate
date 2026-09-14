import Foundation
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("UserDefaults settings adapter")
struct UserDefaultsStoreTests {
    @Test func settingsPersistAndRemoveThroughTheAdapter() throws {
        let suite = "OpenDictateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsStore(defaults)
        let settings = Settings(store: store, environment: [:])
        settings.language = "de"
        #expect(defaults.string(forKey: Settings.Key.language) == "de")
        defaults.set("en", forKey: Settings.Key.language)
        #expect(settings.language == "en")
        store.removeObject(forKey: Settings.Key.language)
        #expect(defaults.object(forKey: Settings.Key.language) == nil)
    }
}
