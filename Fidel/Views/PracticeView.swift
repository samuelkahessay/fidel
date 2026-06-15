import SwiftUI
import SwiftData

struct PracticeHubView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedMode: PracticeMode?
    @State private var progress: UserProgress?

    private let modes: [PracticeMode] = [
        .flashcards,
        .quiz,
        .sentenceBuilder,
        .speedDrill,
        .pronunciation,
        .tracing
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    FidelScreenHeader(
                        title: "Practice",
                        amharicTitle: "ልምምድ",
                        subtitle: "Short, focused rounds for recall, sound, sentence rhythm, and Fidel muscle memory."
                    )

                    recommendedReviewCard
                    modeList
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .background(FidelPaperBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedMode) { mode in
                PracticeHubDestination(mode: mode)
            }
        }
        .task {
            refreshProgress()
        }
        .onAppear {
            refreshProgress()
        }
    }

    private var recommendedReviewCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.onAccentColor)
                    .frame(width: 52, height: 52)
                    .background(AppTheme.eucalyptusColor, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Recommended review")
                        .font(AppTheme.Typography.title3)
                        .foregroundStyle(AppTheme.inkColor)

                    Text(recommendedSubtitle)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                selectedMode = .flashcards
            } label: {
                HStack {
                    Text("Start flashcards")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.onAccentColor)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.eucalyptusColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .fidelDesignCard(padding: AppTheme.Spacing.lg)
    }

    private var modeList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FidelSectionLabel(title: "Modes")

            ForEach(modes) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: mode.icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(mode.color)
                            .frame(width: 46, height: 46)
                            .background(mode.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.rawValue)
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.inkColor)

                            Text(mode.description)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.inkSecondaryColor)
                                .lineLimit(2)
                        }

                        Spacer(minLength: AppTheme.Spacing.sm)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.mutedInkColor)
                    }
                    .fidelDesignCard(padding: AppTheme.Spacing.md, cornerRadius: 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recommendedSubtitle: String {
        guard let progress else {
            return "Build a quick recall loop from the local phrase and vocabulary library."
        }

        let lessonCount = progress.lessonsCompleted.count
        if lessonCount == 0 {
            return "Start with the words already bundled in Fidel, then come back after your first lesson."
        }

        return "You have \(lessonCount) completed lesson\(lessonCount == 1 ? "" : "s"). Keep those words active before moving on."
    }

    private func refreshProgress() {
        let repository = ProgressRepository(modelContext: modelContext)
        progress = repository.ensureUserProgress()
    }
}

private struct PracticeHubDestination: View {
    let mode: PracticeMode

    var body: some View {
        switch mode {
        case .flashcards:
            FlashcardView()
        case .quiz:
            QuizView()
        case .sentenceBuilder:
            SentenceBuilderView()
        case .speedDrill:
            SpeedDrillView()
        case .pronunciation:
            PronunciationPracticeView()
        case .tracing:
            TracingSessionView()
        }
    }
}

struct SpeedDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var timeRemaining = 60
    @State private var isActive = true
    @State private var showResult = false
    @State private var userInput = ""
    @State private var showAnswer = false
    @State private var phrases: [Phrase] = []

    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var currentPhrase: Phrase? {
        currentIndex < phrases.count ? phrases[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Score: \(score)")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.inkColor)
                    Text("\(currentIndex)/\(phrases.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }

                Spacer()

                CountdownTimer(seconds: timeRemaining)
            }
            .padding(AppTheme.Spacing.md)

            if let phrase = currentPhrase, !showResult {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Text("Translate to Amharic:")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.inkSecondaryColor)

                    Text(phrase.english)
                        .font(AppTheme.Typography.title2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.inkColor)

                    if showAnswer {
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Text(phrase.amharic)
                                .font(AppTheme.Typography.amharic(size: 40))
                                .foregroundStyle(AppTheme.primaryColor)
                            Text(phrase.transliteration)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.inkSecondaryColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    HStack(spacing: AppTheme.Spacing.sm) {
                        Button(action: {
                            withAnimation(AppTheme.Animation.standard) {
                                showAnswer = true
                            }
                        }) {
                            SpeedDrillActionButton(title: "Show", systemImage: "eye", style: .secondary, isDisabled: showAnswer)
                        }
                        .buttonStyle(.plain)
                        .disabled(showAnswer)

                        Button(action: { markCorrect() }) {
                            SpeedDrillActionButton(title: "Correct", systemImage: "checkmark", style: .primary)
                        }
                        .buttonStyle(.plain)

                        Button(action: { nextQuestion() }) {
                            SpeedDrillActionButton(title: "Skip", systemImage: "forward", style: .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppTheme.Spacing.md)
            } else if showResult {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Time's Up!")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.inkColor)

                    Text("Final Score: \(score)/\(phrases.count)")
                        .font(AppTheme.Typography.title2)
                        .foregroundStyle(AppTheme.inkSecondaryColor)

                    XPBadge(xp: score * 5)

                    Button("Done") {
                        dismiss()
                    }
                    .primaryGlassButton()
                }
            }

            Spacer()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Speed Drill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .onReceive(timer) { _ in
            guard isActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isActive = false
                showResult = true
            }
        }
        .onAppear {
            phrases = Array(lessonRepository.getPhrases().shuffled().prefix(20))
        }
    }

    private func markCorrect() {
        score += 1
        nextQuestion()
    }

    private func nextQuestion() {
        showAnswer = false
        if currentIndex < phrases.count - 1 {
            currentIndex += 1
        } else {
            showResult = true
            isActive = false
        }
    }
}

private struct SpeedDrillActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    let style: Style
    var isDisabled = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .imageScale(.medium)

            Text(title)
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, AppTheme.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(background)
        .opacity(isDisabled ? 0.48 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Capsule().fill(AppTheme.primaryColor)
        case .secondary:
            Capsule()
                .fill(AppTheme.cardColor.opacity(0.55))
                .overlay(
                    Capsule().stroke(AppTheme.primaryColor.opacity(0.5), lineWidth: 1.5)
                )
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            AppTheme.onAccentColor
        case .secondary:
            AppTheme.primaryColor
        }
    }
}
