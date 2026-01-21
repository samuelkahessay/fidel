import SwiftUI
import SwiftData

struct PracticeView: View {
    @State private var selectedMode: PracticeMode?
    
    enum PracticeMode: String, CaseIterable, Identifiable {
        case flashcards = "Flashcards"
        case quiz = "Quiz"
        case pronunciation = "Pronunciation"
        case sentenceBuilder = "Sentence Builder"
        case speedDrill = "Speed Drill"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .flashcards: return "rectangle.stack.fill"
            case .quiz: return "questionmark.circle.fill"
            case .pronunciation: return "waveform.and.mic"
            case .sentenceBuilder: return "text.word.spacing"
            case .speedDrill: return "timer"
            }
        }
        
        var description: String {
            switch self {
            case .flashcards: return "Review vocabulary with spaced repetition"
            case .quiz: return "Test your knowledge with multiple choice"
            case .pronunciation: return "Listen and practice speaking"
            case .sentenceBuilder: return "Build sentences using patterns"
            case .speedDrill: return "Rapid-fire translation practice"
            }
        }
        
        var color: Color {
            switch self {
            case .flashcards: return .blue
            case .quiz: return .purple
            case .pronunciation: return AppTheme.primaryColor
            case .sentenceBuilder: return .orange
            case .speedDrill: return AppTheme.accentRed
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    dailyGoalSection
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                        ForEach(PracticeMode.allCases) { mode in
                            PracticeModeCard(mode: mode)
                                .onTapGesture {
                                    selectedMode = mode
                                }
                        }
                    }
                    
                    reviewDueSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Practice")
            .navigationDestination(item: $selectedMode) { mode in
                switch mode {
                case .flashcards:
                    FlashcardView()
                case .quiz:
                    QuizView()
                case .pronunciation:
                    PronunciationPracticeView()
                case .sentenceBuilder:
                    SentenceBuilderView()
                case .speedDrill:
                    SpeedDrillView()
                }
            }
        }
    }
    
    private var dailyGoalSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Daily Goal")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.primary)
                    Text("Practice every day to build your streak!")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StreakBadge(streak: 5)
            }
            
            GlassProgressBar(progress: 0.6)
            
            HStack {
                Text("30/50 XP today")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("60%")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.primaryColor)
            }
        }
        .glassCard()
    }
    
    private var reviewDueSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Due for Review")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("15 items")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: AppTheme.Spacing.sm) {
                ReviewCategoryBadge(category: "Vocabulary", count: 8, color: .blue)
                ReviewCategoryBadge(category: "Phrases", count: 5, color: AppTheme.primaryColor)
                ReviewCategoryBadge(category: "Patterns", count: 2, color: .orange)
            }
            
            Button(action: { selectedMode = .flashcards }) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "play.fill")
                    Text("Start Review Session")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .glassCard()
    }
}

struct PracticeModeCard: View {
    @Environment(\.colorScheme) var colorScheme
    let mode: PracticeView.PracticeMode
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: mode.icon)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [mode.color, mode.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(mode.color.opacity(0.12))
                )
            
            Text(mode.rawValue)
                .font(AppTheme.Typography.headline)
                .foregroundColor(.primary)
            
            Text(mode.description)
                .font(AppTheme.Typography.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(AppTheme.Animation.quick, value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct ReviewCategoryBadge: View {
    let category: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text("\(count)")
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(category)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(color.opacity(0.1))
        )
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
                        .foregroundColor(.primary)
                    Text("\(currentIndex)/\(phrases.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CountdownTimer(seconds: timeRemaining)
            }
            .padding(AppTheme.Spacing.md)
            
            if let phrase = currentPhrase, !showResult {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Text("Translate to Amharic:")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(phrase.english)
                        .font(AppTheme.Typography.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    if showAnswer {
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Text(phrase.amharic)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(AppTheme.primaryColor)
                            Text(phrase.transliteration)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    HStack(spacing: AppTheme.Spacing.md) {
                        Button(action: {
                            withAnimation(AppTheme.Animation.standard) {
                                showAnswer = true
                            }
                        }) {
                            Label("Show", systemImage: "eye")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(showAnswer)
                        
                        Button(action: { markCorrect() }) {
                            Label("Correct", systemImage: "checkmark")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button(action: { nextQuestion() }) {
                            Label("Skip", systemImage: "forward")
                        }
                        .buttonStyle(SecondaryButtonStyle())
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
                        .foregroundColor(.primary)
                    
                    Text("Final Score: \(score)/\(phrases.count)")
                        .font(AppTheme.Typography.title2)
                        .foregroundColor(.secondary)
                    
                    XPBadge(xp: score * 5)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Speed Drill")
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    PracticeView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
