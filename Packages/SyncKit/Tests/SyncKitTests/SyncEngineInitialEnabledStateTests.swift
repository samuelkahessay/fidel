import Testing
import Foundation
@testable import SyncKit

/// Default-on semantics: an unset default means the user never chose, so
/// sync should be treated as enabled (invisible sync per the design spec).
/// Once the user makes an explicit choice, that stored bool is respected.
struct SyncEngineInitialEnabledStateTests {
    private func makeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "SyncEngineInitialEnabledStateTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func unsetDefaultsMeansEnabled() {
        let defaults = makeDefaults("unset")
        defer { defaults.removePersistentDomain(forName: "SyncEngineInitialEnabledStateTests.unset") }
        #expect(SyncEngine.initialEnabledState(defaults: defaults) == true)
    }

    @Test func explicitFalseStaysDisabled() {
        let defaults = makeDefaults("false")
        defer { defaults.removePersistentDomain(forName: "SyncEngineInitialEnabledStateTests.false") }
        defaults.set(false, forKey: SyncEngine.enabledDefaultsKey)
        #expect(SyncEngine.initialEnabledState(defaults: defaults) == false)
    }

    @Test func explicitTrueStaysEnabled() {
        let defaults = makeDefaults("true")
        defer { defaults.removePersistentDomain(forName: "SyncEngineInitialEnabledStateTests.true") }
        defaults.set(true, forKey: SyncEngine.enabledDefaultsKey)
        #expect(SyncEngine.initialEnabledState(defaults: defaults) == true)
    }
}
