import SwiftData
import XCTest
@testable import Fidel___Learn_Amharic

/// One merge policy for `UserProgress`, shared by local duplicate consolidation
/// (`ProgressRepository`) and CloudKit merges (`FidelSyncStore`).
final class UserProgressMergeTests: XCTestCase {
    private let older = Date(timeIntervalSince1970: 1_000)
    private let newer = Date(timeIntervalSince1970: 2_000)

    private func state(_ configure: (inout ProgressMergeState) -> Void) -> ProgressMergeState {
        var s = ProgressMergeState()
        configure(&s)
        return s
    }

    func testNonMonotonicFieldsComeFromTheNewerSide() {
        let stale = state {
            $0.syncModifiedAt = older
            $0.currentStreak = 9; $0.todayXP = 40; $0.dailyGoal = 100
            $0.streakFreezesAvailable = 2; $0.weeklyStreakCount = 5
            $0.lessonsInProgress = [1, 2]; $0.lastPracticeDate = older
        }
        let fresh = state {
            $0.syncModifiedAt = newer
            $0.currentStreak = 1; $0.todayXP = 0; $0.dailyGoal = 20
            $0.streakFreezesAvailable = 0; $0.weeklyStreakCount = 0
            $0.lessonsInProgress = [2]; $0.lastPracticeDate = newer
        }

        for merged in [stale.merged(with: fresh), fresh.merged(with: stale)] {
            XCTAssertEqual(merged.currentStreak, 1, "a spent streak must not be restored")
            XCTAssertEqual(merged.todayXP, 0)
            XCTAssertEqual(merged.dailyGoal, 20)
            XCTAssertEqual(merged.streakFreezesAvailable, 0, "a spent freeze must not be refunded")
            XCTAssertEqual(merged.weeklyStreakCount, 0)
            XCTAssertEqual(merged.lessonsInProgress, [2], "lessonsInProgress has removal semantics")
            XCTAssertEqual(merged.lastPracticeDate, newer)
            XCTAssertEqual(merged.syncModifiedAt, newer)
        }
    }

    func testTimestampTieKeepsTheReceiver() {
        let mine = state { $0.syncModifiedAt = older; $0.currentStreak = 3 }
        let theirs = state { $0.syncModifiedAt = older; $0.currentStreak = 7 }
        XCTAssertEqual(mine.merged(with: theirs).currentStreak, 3)
    }

    func testMonotonicCountersTakeTheMaximum() {
        let a = state { $0.syncModifiedAt = newer; $0.totalXP = 10; $0.longestStreak = 2; $0.currentStage = 1; $0.lastFreezeGrantWeek = 202601 }
        let b = state { $0.syncModifiedAt = older; $0.totalXP = 50; $0.longestStreak = 8; $0.currentStage = 3; $0.lastFreezeGrantWeek = 202650 }
        let merged = a.merged(with: b)
        XCTAssertEqual(merged.totalXP, 50)
        XCTAssertEqual(merged.longestStreak, 8)
        XCTAssertEqual(merged.currentStage, 3)
        XCTAssertEqual(merged.lastFreezeGrantWeek, 202650)
    }

    func testAdditiveArraysUnionInReceiverOrder() {
        let a = state { $0.lessonsCompleted = [3, 1]; $0.achievements = ["first"] }
        let b = state { $0.lessonsCompleted = [1, 2]; $0.achievements = ["streak", "first"] }
        let merged = a.merged(with: b)
        XCTAssertEqual(merged.lessonsCompleted, [3, 1, 2])
        XCTAssertEqual(merged.achievements, ["first", "streak"])
    }

    func testConvergenceIgnoresArrayOrder() {
        let a = state { $0.lessonsCompleted = [1, 2]; $0.charactersTraced = ["a", "b"] }
        let b = state { $0.lessonsCompleted = [2, 1]; $0.charactersTraced = ["b", "a"] }
        XCTAssertTrue(a.converges(with: b))
        XCTAssertFalse(a.converges(with: state { $0.totalXP = 1 }))
    }

    /// Regression: local duplicate consolidation used `max` for streak fields,
    /// restoring a broken streak and refunding a spent freeze.
    @MainActor
    func testRepositoryConsolidationUsesTheSharedPolicy() throws {
        let schema = Schema([
            UserProgress.self, FlashcardProgress.self, SelamConversation.self,
            SelamMessage.self, CharacterTraceMastery.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = container.mainContext

        let stale = UserProgress(ownerUserId: LocalLearner.userId)
        stale.totalXP = 500
        stale.currentStreak = 9
        stale.streakFreezesAvailable = 2
        stale.lessonsCompleted = [1]
        stale.syncModifiedAt = older
        let fresh = UserProgress(ownerUserId: LocalLearner.userId)
        fresh.totalXP = 100
        fresh.currentStreak = 1
        fresh.streakFreezesAvailable = 0
        fresh.lessonsCompleted = [2]
        fresh.syncModifiedAt = newer
        context.insert(stale)
        context.insert(fresh)
        try context.save()

        let progress = try XCTUnwrap(ProgressRepository(modelContext: context).getUserProgress())

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProgress>()), 1)
        XCTAssertEqual(progress.totalXP, 500)
        XCTAssertEqual(Set(progress.lessonsCompleted), [1, 2])
        XCTAssertEqual(progress.currentStreak, 1)
        XCTAssertEqual(progress.streakFreezesAvailable, 0)
    }
}
