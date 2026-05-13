import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    private let settingsStore = AppSettingsStore()
    @State private var dailyGoal = AppSettingsStore.defaultDailyXPGoal
    @State private var progress: UserProgress?
    @State private var exportDocument: ProgressBackupDocument?
    @State private var isImportingBackup = false
    @State private var backupMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    FidelScreenHeader(
                        title: "You",
                        amharicTitle: "አንተ",
                        subtitle: "Your local learning record, preferences, achievements, and backup controls."
                    )
                    youHeroSection
                    metricGrid
                    dailyGoalSection
                    achievementsSection
                    localSaveStatusSection
                    backupSection
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, 110)
            }
            .background(FidelPaperBackground())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                loadProgress()
            }
            .fileExporter(
                isPresented: Binding(
                    get: { exportDocument != nil },
                    set: { if !$0 { exportDocument = nil } }
                ),
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Fidel Progress Backup"
            ) { result in
                if case .failure(let error) = result {
                    backupMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
        }
    }
    
    private var currentStage: LearningStage {
        LearningStage(rawValue: progress?.currentStage ?? 0) ?? .scriptAndSounds
    }

    private var level: Int {
        max((progress?.totalXP ?? 0) / 100 + 1, 1)
    }

    private var levelProgress: Double {
        Double((progress?.totalXP ?? 0) % 100) / 100.0
    }

    private var youHeroSection: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.lg) {
            YouLevelRing(level: level, progress: levelProgress)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(currentStage.displayName)
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.inkColor)

                Text(currentStage.amharicTitle)
                    .font(AppTheme.Typography.amharicDisplay(size: 28, relativeTo: .title))
                    .foregroundStyle(currentStage.color)

                Text("\((progress?.totalXP ?? 0) % 100) of 100 XP toward the next level")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)

                FidelProgressBar(value: levelProgress, color: currentStage.color)
            }
        }
        .fidelDesignCard(padding: AppTheme.Spacing.lg)
    }

    private var metricGrid: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FidelSectionLabel(title: "Learning record")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                FidelMetricTile(
                    icon: "bolt.fill",
                    value: "\(progress?.totalXP ?? 0)",
                    label: "Total XP",
                    subtitle: "earned",
                    color: AppTheme.goldColor
                )

                FidelMetricTile(
                    icon: "flame.fill",
                    value: "\(progress?.currentStreak ?? 0)",
                    label: "Streak",
                    subtitle: "days",
                    color: AppTheme.terracottaColor
                )

                FidelMetricTile(
                    icon: "book.fill",
                    value: "\(progress?.lessonsCompleted.count ?? 0)",
                    label: "Lessons",
                    subtitle: "complete",
                    color: AppTheme.eucalyptusColor
                )

                FidelMetricTile(
                    icon: "character.textbox",
                    value: "\(progress?.fidelCharactersRecognized.count ?? 0)",
                    label: "Fidel",
                    subtitle: "recognized",
                    color: AppTheme.plumColor
                )
            }
        }
    }

    private var localSaveStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.title3)
                .foregroundStyle(AppTheme.terracottaColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Saved on This Device")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                Text("Your progress is saved automatically on this device. No setup required.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            Spacer()
        }
        .fidelDesignCard()
        .accessibilityElement(children: .combine)
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Local Backup", systemImage: "externaldrive.fill")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                Spacer()
            }

            Text("Export a backup file you control, or import one from Files to restore progress on this device.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)

            HStack(spacing: 12) {
                Button {
                    exportBackup()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    isImportingBackup = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if let backupMessage {
                Text(backupMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
        }
        .fidelDesignCard()
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
                                .fill(isUnlocked ? stage.color : AppTheme.mutedInkColor.opacity(0.2))
                                .frame(width: 36, height: 36)

                            if stage < currentStage {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.onAccentColor)
                            } else if isCurrent {
                                Image(systemName: stage.icon)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.onAccentColor)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.mutedInkColor)
                            }
                        }

                        Text(stage.displayName)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(isCurrent ? stage.color : AppTheme.inkSecondaryColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(stage.displayName)
                    .accessibilityValue(isCurrent ? "Current stage" : (isUnlocked ? "Unlocked" : "Locked"))

                    if stage != .fluency {
                        Rectangle()
                            .fill(stage < currentStage ? stage.color : AppTheme.mutedInkColor.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: 20)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .fidelSurface(.solid)
    }

    private var statsOverview: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    statCards
                }
            } else {
                HStack(spacing: 16) {
                    statCards
                }
            }
        }
    }

    @ViewBuilder
    private var statCards: some View {
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
            color: AppTheme.warningColor
        )

        StatCard(
            title: "Lessons",
            value: "\(progress?.lessonsCompleted.count ?? 0)",
            icon: "book.fill",
            color: AppTheme.primaryColor
        )
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
                            .fill(day < (progress?.currentStreak ?? 0) % 7 ? AppTheme.primaryColor : AppTheme.mutedInkColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Text(dayLabel(day))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.inkSecondaryColor)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            if let longest = progress?.longestStreak, longest > 0 {
                Text("Longest streak: \(longest) days")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
        }
        .fidelSurface(.solid)
    }
    
    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FidelSectionLabel(title: "Daily goal")
                Spacer()
                Text("\(progress?.todayXP ?? 0)/\(dailyGoal) XP")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            
            let goalProgress = min(Double(progress?.todayXP ?? 0) / Double(dailyGoal), 1.0)
            
            FidelProgressBar(
                value: goalProgress,
                color: goalProgress >= 1.0 ? AppTheme.successColor : AppTheme.terracottaColor,
                trackColor: AppTheme.terracottaColor.opacity(0.13),
                height: 9
            )
                .accessibilityLabel("Daily goal progress")
                .accessibilityValue("\(progress?.todayXP ?? 0) of \(dailyGoal) XP")

            Stepper(value: dailyGoalBinding, in: 10...500, step: 10) {
                Text("Goal: \(dailyGoal) XP")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkColor)
            }
            
            if goalProgress >= 1.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.successColor)
                    Text("Daily goal achieved!")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.successColor)
                }
            }
        }
        .fidelDesignCard()
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FidelSectionLabel(title: "Achievements")
                Spacer()
                Text("\(earnedAchievements.count)/\(allAchievements.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
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
        .fidelDesignCard()
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
                    color: AppTheme.infoColor
                )
                
                LearningStat(
                    title: "Vocabulary",
                    count: progress?.vocabularyMastered.count ?? 0,
                    total: lessonRepository.getVocabulary().count,
                    color: AppTheme.successColor
                )
                
                LearningStat(
                    title: "Conversations",
                    count: progress?.conversationsPracticed.count ?? 0,
                    total: lessonRepository.getConversations().count,
                    color: AppTheme.practiceColor
                )
            }
        }
        .fidelSurface(.solid)
    }
    
    private func dayLabel(_ index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[index]
    }

    private func loadProgress() {
        let repo = ProgressRepository(modelContext: modelContext)
        progress = repo.ensureUserProgress()
        dailyGoal = settingsStore.dailyXPGoal
        progress?.dailyGoal = dailyGoal
    }

    private var dailyGoalBinding: Binding<Int> {
        Binding(
            get: { dailyGoal },
            set: { newValue in
                dailyGoal = newValue
                settingsStore.dailyXPGoal = newValue
                progress?.dailyGoal = newValue
                progress?.updatedAt = Date.now
            }
        )
    }

    private func exportBackup() {
        do {
            let data = try ProgressExportService(modelContext: modelContext, settingsStore: settingsStore).exportData()
            exportDocument = ProgressBackupDocument(data: data)
            backupMessage = "Backup ready to export."
        } catch {
            backupMessage = "Could not create backup: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            try ProgressExportService(modelContext: modelContext, settingsStore: settingsStore).importData(data)
            loadProgress()
            backupMessage = "Backup imported on this device."
        } catch {
            backupMessage = "Could not import backup: \(error.localizedDescription)"
        }
    }
}

private struct YouLevelRing: View {
    let level: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.goldColor.opacity(0.18), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    AppTheme.goldColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("LV")
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                Text("\(level)")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.inkColor)
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level)")
    }
}

struct ProgressBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .fidelSurface(.muted, padding: AppTheme.Spacing.md, cornerRadius: AppTheme.CornerRadius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let isEarned: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isEarned ? AppTheme.secondaryColor : AppTheme.mutedInkColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundStyle(isEarned ? AppTheme.onAccentColor : AppTheme.mutedInkColor)
            }
            
            Text(achievement.title)
                .font(.caption2)
                .foregroundStyle(isEarned ? AppTheme.inkColor : AppTheme.inkSecondaryColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .opacity(isEarned ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(achievement.title)
        .accessibilityValue(isEarned ? "Earned" : "Locked")
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
                AccessibleProgressRing(
                    progress: progress,
                    lineWidth: 6,
                    size: 50,
                    label: "\(title) progress",
                    valueText: "\(count) of \(total)"
                )
                
                Text("\(Int(progress * 100))%")
                    .font(.caption2.bold())
            }
            
            Text("\(count)/\(total)")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSecondaryColor)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(count) of \(total)")
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
