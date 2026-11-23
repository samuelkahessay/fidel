import XCTest

@testable import Fidel___Learn_Amharic

final class DailyGoalTierTests: XCTestCase {
    func testRegularPreservesLegacyTracingDefault() {
        // The redesign must not change existing users' tracing session size.
        XCTAssertEqual(DailyGoalTier.default, .regular)
        XCTAssertEqual(DailyGoalTier.regular.tracingSessionSize, 8)
    }

    func testCapsIncreaseMonotonicallyWithTier() {
        let order: [DailyGoalTier] = [.casual, .regular, .serious, .intense]
        XCTAssertEqual(order.map(\.newCap), [3, 5, 8, 12])
        XCTAssertEqual(order.map(\.reviewCap), [10, 15, 20, 30])
        XCTAssertEqual(order.map(\.tracingSessionSize), [5, 8, 12, 16])
        XCTAssertEqual(order.map(\.suggestedDailyXP), [10, 20, 30, 50])
    }

    func testAllCasesHaveNonEmptyLabels() {
        for tier in DailyGoalTier.allCases {
            XCTAssertFalse(tier.displayName.isEmpty)
            XCTAssertFalse(tier.subtitle.isEmpty)
        }
    }
}
