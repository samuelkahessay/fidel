import SwiftUI
import SwiftData
import SyncKit
import UniformTypeIdentifiers

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    private let settingsStore = AppSettingsStore()
    @State private var dailyGoal = AppSettingsStore.defaultDailyXPGoal
    @State private var dailyGoalTier: DailyGoalTier = .default
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
                    paceSection
                    dailyGoalSection
                    achievementsSection
                    localSaveStatusSection
                    SyncSettingsSection(engine: sync)
                    backupSection
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
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
                .secondaryGlassButton()

                Button {
                    isImportingBackup = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .secondaryGlassButton()
            }

            if let backupMessage {
                Text(backupMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
        }
        .fidelDesignCard()
    }

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FidelSectionLabel(title: "Pace")

            Picker("Pace", selection: dailyGoalTierBinding) {
                ForEach(DailyGoalTier.allCases) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)

            Text(dailyGoalTier.subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)
        }
        .fidelDesignCard()
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

    private func loadProgress() {
        let repo = ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
        progress = repo.ensureUserProgress()
        dailyGoal = settingsStore.dailyXPGoal
        dailyGoalTier = settingsStore.dailyGoalTier
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
                progress?.syncModifiedAt = Date.now
                if let progress { sync.markPending(progress.syncID) }
            }
        )
    }

    private var dailyGoalTierBinding: Binding<DailyGoalTier> {
        Binding(
            get: { dailyGoalTier },
            set: { newValue in
                dailyGoalTier = newValue
                settingsStore.dailyGoalTier = newValue
                dailyGoal = newValue.suggestedDailyXP
                settingsStore.dailyXPGoal = newValue.suggestedDailyXP
                progress?.dailyGoal = newValue.suggestedDailyXP
                progress?.updatedAt = Date.now
                progress?.syncModifiedAt = Date.now
                if let progress { sync.markPending(progress.syncID) }
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
            try ProgressExportService(
                modelContext: modelContext,
                settingsStore: settingsStore,
                onMutation: { sync.markPending($0) }
            ).importData(data)
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
        GoldProgressRing(
            progress: progress,
            lineWidth: 10,
            size: 104,
            accessibilityLabel: "Level \(level)"
        ) {
            VStack(spacing: 2) {
                Text("LV")
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                Text("\(level)")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.inkColor)
            }
        }
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

#Preview {
    ProgressDashboardView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
