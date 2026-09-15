import OpenDictateCore
import Testing

@Suite("Panel target focus")
struct PanelTargetPolicyTests {
    @Test func returnsOnlyToUnchangedTarget() {
        #expect(PanelTargetPolicy.canReturnFocus(target: 10, latestExternal: 10))
        #expect(!PanelTargetPolicy.canReturnFocus(target: 10, latestExternal: 20))
        #expect(!PanelTargetPolicy.canReturnFocus(target: 10, latestExternal: nil))
        #expect(!PanelTargetPolicy.canReturnFocus(target: nil, latestExternal: 10))
        #expect(!PanelTargetPolicy.canReturnFocus(target: nil, latestExternal: nil))
    }
}
