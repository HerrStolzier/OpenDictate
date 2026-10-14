import XCTest

@testable import OpenDictateiOS

/// The Live Activity's state, as iOS stores it between app versions.
final class ActivityStateTests: XCTestCase {
    func testStateOfAnEarlierVersionDecodes() throws {
        let earlier = Data(#"{"phase":"writing","startedAt":0,"endsAt":90}"#.utf8)
        let state = try JSONDecoder().decode(DictationAttributes.ContentState.self, from: earlier)
        XCTAssertEqual(state.phase, .writing)
        XCTAssertFalse(state.setsUpModel)
        XCTAssertNil(state.shownDetail)
    }

    func testSetupShowsItsHintAfterARoundTrip() throws {
        var state = DictationAttributes.ContentState(
            phase: .writing, startedAt: Date(timeIntervalSince1970: 0), endsAt: Date(timeIntervalSince1970: 90))
        state.setsUpModel = true
        let decoded = try JSONDecoder().decode(
            DictationAttributes.ContentState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.shownDetail, L10n.modelLoadsDetail)
    }
}
