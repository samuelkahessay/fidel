import Foundation

@Observable
final class ProgressDashboardViewModel {
    private var progressRepository: ProgressRepositoryProtocol?

    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    var currentStage: LearningStage {
        LearningStage(rawValue: progressRepository?.getCurrentStage() ?? 0) ?? .scriptAndSounds
    }

    var allStages: [(stage: LearningStage, isUnlocked: Bool)] {
        let current = currentStage
        return LearningStage.allCases.map { ($0, $0 <= current) }
    }

    var totalXP: Int {
        progressRepository?.getTotalXP() ?? 0
    }

    var todayXP: Int {
        progressRepository?.getTodayXP() ?? 0
    }

    var dailyGoal: Int {
        progressRepository?.getDailyGoal() ?? 50
    }

    var currentStreak: Int {
        progressRepository?.getCurrentStreak() ?? 0
    }

    var lessonsCompleted: Int {
        progressRepository?.getLessonsCompletedCount() ?? 0
    }

    var vocabularyMastered: Int {
        progressRepository?.getVocabularyMasteredCount() ?? 0
    }

    var achievements: [String] {
        progressRepository?.getAchievements() ?? []
    }

    var dailyProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayXP) / Double(dailyGoal), 1.0)
    }

    var level: Int {
        totalXP / 100 + 1
    }

    var xpToNextLevel: Int {
        100 - (totalXP % 100)
    }
}
