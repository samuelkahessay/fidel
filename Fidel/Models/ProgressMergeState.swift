import Foundation

/// The mergeable state of a `UserProgress`, as a plain value.
///
/// `merged(with:)` is the single merge policy for learner progress. Local
/// duplicate consolidation (`ProgressRepository`) and CloudKit merges
/// (`FidelSyncStore`) both go through it, so two devices converge on the
/// same result whichever path brings their records together.
struct ProgressMergeState: Equatable {
    // Additive history: union, keeping the receiver's order.
    var lessonsCompleted: [Int] = []
    var patternsLearned: [String] = []
    var vocabularyMastered: [String] = []
    var conversationsPracticed: [Int] = []
    var achievements: [String] = []
    var fidelCharactersRecognized: [String] = []
    var charactersTraced: [String] = []

    // Monotonic counters: only ever grow, so take the maximum.
    var totalXP = 0
    var longestStreak = 0
    var currentStage = 0
    var lastFreezeGrantWeek = 0

    // Non-monotonic state: consumed, reset or removed over time, so the side
    // edited most recently wins wholesale. `max` here would restore a broken
    // streak, refund a spent freeze, or never let a lesson leave "in progress".
    var currentStreak = 0
    var lastPracticeDate: Date?
    var todayXP = 0
    var dailyGoal = 0
    var lessonsInProgress: [Int] = []
    var streakFreezesAvailable = 0
    var weeklyStreakCount = 0

    var updatedAt = Date.distantPast
    var syncModifiedAt = Date.distantPast

    /// Merges `other` into this state. On a timestamp tie the receiver wins.
    func merged(with other: ProgressMergeState) -> ProgressMergeState {
        var result = self

        result.lessonsCompleted = Self.union(lessonsCompleted, other.lessonsCompleted)
        result.patternsLearned = Self.union(patternsLearned, other.patternsLearned)
        result.vocabularyMastered = Self.union(vocabularyMastered, other.vocabularyMastered)
        result.conversationsPracticed = Self.union(conversationsPracticed, other.conversationsPracticed)
        result.achievements = Self.union(achievements, other.achievements)
        result.fidelCharactersRecognized = Self.union(fidelCharactersRecognized, other.fidelCharactersRecognized)
        result.charactersTraced = Self.union(charactersTraced, other.charactersTraced)

        result.totalXP = max(totalXP, other.totalXP)
        result.longestStreak = max(longestStreak, other.longestStreak)
        result.currentStage = max(currentStage, other.currentStage)
        result.lastFreezeGrantWeek = max(lastFreezeGrantWeek, other.lastFreezeGrantWeek)

        if other.syncModifiedAt > syncModifiedAt {
            result.currentStreak = other.currentStreak
            result.lastPracticeDate = other.lastPracticeDate
            result.todayXP = other.todayXP
            result.dailyGoal = other.dailyGoal
            result.lessonsInProgress = other.lessonsInProgress
            result.streakFreezesAvailable = other.streakFreezesAvailable
            result.weeklyStreakCount = other.weeklyStreakCount
        }

        result.updatedAt = max(updatedAt, other.updatedAt)
        result.syncModifiedAt = max(syncModifiedAt, other.syncModifiedAt)
        return result
    }

    /// Whether both sides hold the same learner state, comparing additive
    /// history as sets. Two devices holding the same set in different orders
    /// would otherwise never compare equal and re-upload forever.
    func converges(with other: ProgressMergeState) -> Bool {
        Set(lessonsCompleted) == Set(other.lessonsCompleted)
            && Set(patternsLearned) == Set(other.patternsLearned)
            && Set(vocabularyMastered) == Set(other.vocabularyMastered)
            && Set(conversationsPracticed) == Set(other.conversationsPracticed)
            && Set(achievements) == Set(other.achievements)
            && Set(fidelCharactersRecognized) == Set(other.fidelCharactersRecognized)
            && Set(charactersTraced) == Set(other.charactersTraced)
            && lessonsInProgress == other.lessonsInProgress
            && totalXP == other.totalXP
            && longestStreak == other.longestStreak
            && currentStage == other.currentStage
            && lastFreezeGrantWeek == other.lastFreezeGrantWeek
            && currentStreak == other.currentStreak
            && lastPracticeDate == other.lastPracticeDate
            && todayXP == other.todayXP
            && dailyGoal == other.dailyGoal
            && streakFreezesAvailable == other.streakFreezesAvailable
            && weeklyStreakCount == other.weeklyStreakCount
    }

    private static func union<T: Equatable>(_ base: [T], _ extra: [T]) -> [T] {
        var result = base
        for element in extra where !result.contains(element) {
            result.append(element)
        }
        return result
    }
}

extension UserProgress {
    var mergeState: ProgressMergeState {
        ProgressMergeState(
            lessonsCompleted: lessonsCompleted,
            patternsLearned: patternsLearned,
            vocabularyMastered: vocabularyMastered,
            conversationsPracticed: conversationsPracticed,
            achievements: achievements,
            fidelCharactersRecognized: fidelCharactersRecognized,
            charactersTraced: charactersTraced,
            totalXP: totalXP,
            longestStreak: longestStreak,
            currentStage: currentStage,
            lastFreezeGrantWeek: lastFreezeGrantWeek,
            currentStreak: currentStreak,
            lastPracticeDate: lastPracticeDate,
            todayXP: todayXP,
            dailyGoal: dailyGoal,
            lessonsInProgress: lessonsInProgress,
            streakFreezesAvailable: streakFreezesAvailable,
            weeklyStreakCount: weeklyStreakCount,
            updatedAt: updatedAt,
            syncModifiedAt: syncModifiedAt
        )
    }

    func apply(_ state: ProgressMergeState) {
        lessonsCompleted = state.lessonsCompleted
        patternsLearned = state.patternsLearned
        vocabularyMastered = state.vocabularyMastered
        conversationsPracticed = state.conversationsPracticed
        achievements = state.achievements
        fidelCharactersRecognized = state.fidelCharactersRecognized
        charactersTraced = state.charactersTraced
        totalXP = state.totalXP
        longestStreak = state.longestStreak
        currentStage = state.currentStage
        lastFreezeGrantWeek = state.lastFreezeGrantWeek
        currentStreak = state.currentStreak
        lastPracticeDate = state.lastPracticeDate
        todayXP = state.todayXP
        dailyGoal = state.dailyGoal
        lessonsInProgress = state.lessonsInProgress
        streakFreezesAvailable = state.streakFreezesAvailable
        weeklyStreakCount = state.weeklyStreakCount
        updatedAt = state.updatedAt
        syncModifiedAt = state.syncModifiedAt
    }
}
