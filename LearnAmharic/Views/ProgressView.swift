import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Query private var progressItems: [UserProgress]
    
    var progress: UserProgress? {
        progressItems.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
        }
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
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            if let longest = progress?.longestStreak, longest > 0 {
                Text("Longest streak: \(longest) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
            }
            
            let goalProgress = min(Double(progress?.todayXP ?? 0) / Double(progress?.dailyGoal ?? 50), 1.0)
            
            ProgressView(value: goalProgress)
                .tint(goalProgress >= 1.0 ? .green : AppTheme.primaryColor)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            if goalProgress >= 1.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Daily goal achieved!")
                        .font(.subheadline)
                        .foregroundColor(.green)
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
                    .foregroundColor(.secondary)
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
                    total: AmharicData.patterns.count,
                    color: .blue
                )
                
                LearningStat(
                    title: "Vocabulary",
                    count: progress?.vocabularyMastered.count ?? 0,
                    total: AmharicData.vocabulary.count,
                    color: .green
                )
                
                LearningStat(
                    title: "Conversations",
                    count: progress?.conversationsPracticed.count ?? 0,
                    total: AmharicData.conversations.count,
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
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
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
                    .foregroundColor(isEarned ? .white : .gray)
            }
            
            Text(achievement.title)
                .font(.caption2)
                .foregroundColor(isEarned ? .primary : .secondary)
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
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
