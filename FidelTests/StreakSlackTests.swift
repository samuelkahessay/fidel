import SwiftData
import XCTest

@testable import Fidel___Learn_Amharic

/// Tests for streak "slack": auto-granted weekly freezes that absorb a single
/// missed day without resetting `currentStreak`. Unprotected streaks cause
/// learners to quit entirely after the first miss — these tests pin down the
/// grant/consume rules that make a single slip forgivable.
@MainActor
final class StreakSlackTests: XCTestCase {

    /// Containers must outlive the model instances using their contexts.
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self,
            CharacterTraceMastery.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeProgress() throws -> UserProgress {
        let container = try makeContainer()
        retainedContainers.append(container)
        let progress = UserProgress(ownerUserId: LocalLearner.userId)
        container.mainContext.insert(progress)
        return progress
    }

    /// Mirrors the `weekKey` computation inside `checkStreak()` so tests can
    /// pre-seed `lastFreezeGrantWeek` and deterministically suppress (or expect)
    /// a grant on a given call.
    private func currentWeekKey(calendar: Calendar = .current, date: Date = .now) -> Int {
        let today = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return (components.yearForWeekOfYear ?? 0) * 100 + (components.weekOfYear ?? 0)
    }

    private func daysAgo(_ n: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -n, to: Date.now)!
    }

    // MARK: - 1. Missed one day WITH a freeze available

    func testMissedOneDayWithFreezeAvailablePreservesStreakAndConsumesFreeze() throws {
        let progress = try makeProgress()
        progress.currentStreak = 5
        progress.longestStreak = 5
        progress.streakFreezesAvailable = 1
        // Suppress this call's weekly grant so the assertion below isolates consumption.
        progress.lastFreezeGrantWeek = currentWeekKey()
        progress.lastPracticeDate = daysAgo(2)

        progress.checkStreak()

        XCTAssertEqual(progress.currentStreak, 5, "a protected missed day must not reset the streak")
        XCTAssertEqual(progress.streakFreezesAvailable, 0, "the available freeze must be consumed")
    }

    // MARK: - 2. Missed one day WITHOUT a freeze

    func testMissedOneDayWithoutFreezeResetsStreakButLeavesWeeklyCountUnchanged() throws {
        let progress = try makeProgress()
        progress.currentStreak = 5
        progress.longestStreak = 5
        progress.streakFreezesAvailable = 0
        progress.weeklyStreakCount = 3
        // Suppress this call's weekly grant so it can't mask the reset.
        progress.lastFreezeGrantWeek = currentWeekKey()
        progress.lastPracticeDate = daysAgo(2)

        progress.checkStreak()

        XCTAssertEqual(progress.currentStreak, 1, "an unprotected missed day resets the streak")
        XCTAssertEqual(progress.streakFreezesAvailable, 0, "there was no freeze to consume")
        XCTAssertEqual(progress.weeklyStreakCount, 3, "a single missed day must not affect weeklyStreakCount")
    }

    // MARK: - 3. Freezes granted at most once per ISO week

    func testFreezeIsGrantedAtMostOncePerISOWeek() throws {
        let progress = try makeProgress()
        XCTAssertEqual(progress.streakFreezesAvailable, 0)
        XCTAssertEqual(progress.lastFreezeGrantWeek, 0)

        progress.checkStreak()

        XCTAssertEqual(progress.streakFreezesAvailable, 1, "the first check-in of the week should grant a freeze")
        XCTAssertEqual(progress.lastFreezeGrantWeek, currentWeekKey())
        XCTAssertEqual(progress.weeklyStreakCount, 1)

        progress.checkStreak()

        XCTAssertEqual(progress.streakFreezesAvailable, 1, "a second call in the same ISO week must not grant again")
        XCTAssertEqual(progress.weeklyStreakCount, 1, "weeklyStreakCount must not double-increment within a week")
    }
}
