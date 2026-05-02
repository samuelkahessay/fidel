import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    @State private var progress: UserProgress?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    localSaveStatusSection
                    stageTimeline
                    statsOverview
                    streakSection
                    dailyGoalSection
                    achievementsSection
                    learningStatsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .task {
                loadProgress()
            }
        }
    }
    
    private var currentStage: LearningStage {
        LearningStage(rawValue: progress?.currentStage ?? 0) ?? .scriptAndSounds
    }

    private var localSaveStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.title3)
                .foregroundStyle(AppTheme.primaryColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Saved on This Device")
                    .font(AppTheme.Typography.headline)
                Text("Your progress is saved automatically on this device. No account required.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }

    private var stageTimeline: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Learning Journey")
                .font(AppTheme.Typography.headline)

            HStack(spacing: 0) {
                ForEach(LearningStage.allCases) { stage in
                    let isUnlocked = stage <= currentStage
                    let isCurrent = stage == currentStage

                    VStack(spacing: AppTheme.Spacing.xs) {
                        ZStack {
                            Circle()
                                .fill(isUnlocked ? stage.color : Color.gray.opacity(0.2))
                                .frame(width: 36, height: 36)

                            if stage < currentStage {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            } else if isCurrent {
                                Image(systemName: stage.icon)
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }

                        Text(stage.displayName)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(isCurrent ? stage.color : .secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)

                    if stage != .fluency {
                        Rectangle()
                            .fill(stage < currentStage ? stage.color : Color.gray.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: 20)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }

    private var statsOverview: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total XP",
                value: "\(progress?.totalXP ?? 0)",
                icon: "star.fill",
                color: AppTheme.secondaryColor
            )
            
            StatCard(
                title: "Streak",
                value: "\(progress?.currentStreak ?? 0)",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Lessons",
                value: "\(progress?.lessonsCompleted.count ?? 0)",
                icon: "book.fill",
                color: AppTheme.primaryColor
            )
        }
    }
    
    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Streak")
                    .font(.headline)
                Spacer()
                StreakBadge(streak: progress?.currentStreak ?? 0)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<7) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day < (progress?.currentStreak ?? 0) % 7 ? AppTheme.primaryColor : Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Text(dayLabel(day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            if let longest = progress?.longestStreak, longest > 0 {
                Text("Longest streak: \(longest) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Goal")
                    .font(.headline)
                Spacer()
                Text("\(progress?.todayXP ?? 0)/\(progress?.dailyGoal ?? 50) XP")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            let goalProgress = min(Double(progress?.todayXP ?? 0) / Double(progress?.dailyGoal ?? 50), 1.0)
            
            ProgressView(value: goalProgress)
                .tint(goalProgress >= 1.0 ? .green : AppTheme.primaryColor)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            if goalProgress >= 1.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Daily goal achieved!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(earnedAchievements.count)/\(allAchievements.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(allAchievements) { achievement in
                    AchievementBadge(
                        achievement: achievement,
                        isEarned: progress?.achievements.contains(achievement.id) ?? false
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private var earnedAchievements: [Achievement] {
        allAchievements.filter { progress?.achievements.contains($0.id) ?? false }
    }
    
    private var learningStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learning Stats")
                .font(.headline)
            
            HStack(spacing: 16) {
                LearningStat(
                    title: "Patterns",
                    count: progress?.patternsLearned.count ?? 0,
                    total: lessonRepository.getPatterns().count,
                    color: .blue
                )
                
                LearningStat(
                    title: "Vocabulary",
                    count: progress?.vocabularyMastered.count ?? 0,
                    total: lessonRepository.getVocabulary().count,
                    color: .green
                )
                
                LearningStat(
                    title: "Conversations",
                    count: progress?.conversationsPracticed.count ?? 0,
                    total: lessonRepository.getConversations().count,
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private func dayLabel(_ index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[index]
    }

    private func loadProgress() {
        let repo = ProgressRepository(modelContext: modelContext)
        progress = repo.getUserProgress()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 4, y: 2)
        )
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let isEarned: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isEarned ? AppTheme.secondaryColor : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundStyle(isEarned ? .white : .gray)
            }
            
            Text(achievement.title)
                .font(.caption2)
                .foregroundStyle(isEarned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .opacity(isEarned ? 1.0 : 0.5)
    }
}

struct LearningStat: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    var progress: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ProgressRing(progress: progress, lineWidth: 6, size: 50)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption2.bold())
            }
            
            Text("\(count)/\(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
