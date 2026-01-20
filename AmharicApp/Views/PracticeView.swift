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
            case .pronunciation: return .green
            case .sentenceBuilder: return .orange
            case .speedDrill: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dailyGoalSection
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(PracticeMode.allCases) { mode in
                            PracticeModeCard(mode: mode)
                                .onTapGesture {
                                    selectedMode = mode
                                }
                        }
                    }
                    .padding(.horizontal)
                    
                    reviewDueSection
                }
                .padding(.vertical)
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
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Daily Goal")
                        .font(.headline)
                    Text("Practice every day to build your streak!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StreakBadge(streak: 5)
            }
            
            ProgressView(value: 0.6)
                .tint(AppTheme.primaryColor)
            
            HStack {
                Text("30/50 XP today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("60%")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.primaryColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var reviewDueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Due for Review")
                    .font(.headline)
                Spacer()
                Text("15 items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                ReviewCategoryBadge(category: "Vocabulary", count: 8, color: .blue)
                ReviewCategoryBadge(category: "Phrases", count: 5, color: .green)
                ReviewCategoryBadge(category: "Patterns", count: 2, color: .orange)
            }
            
            Button(action: { selectedMode = .flashcards }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Review Session")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }
}

struct PracticeModeCard: View {
    let mode: PracticeView.PracticeMode
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: mode.icon)
                .font(.system(size: 32))
                .foregroundColor(mode.color)
            
            Text(mode.rawValue)
                .font(.headline)
            
            Text(mode.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }
}

struct ReviewCategoryBadge: View {
    let category: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundColor(color)
            Text(category)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
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
    
    let phrases = AmharicData.phrases.shuffled().prefix(20)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var currentPhrase: Phrase? {
        currentIndex < phrases.count ? Array(phrases)[currentIndex] : nil
    }
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Score: \(score)")
                        .font(.headline)
                    Text("\(currentIndex)/\(phrases.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(timeRemaining)s")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(timeRemaining < 10 ? .red : AppTheme.primaryColor)
            }
            .padding()
            
            if let phrase = currentPhrase, !showResult {
                VStack(spacing: 20) {
                    Text("Translate to Amharic:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(phrase.english)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    if showAnswer {
                        VStack(spacing: 8) {
                            Text(phrase.amharic)
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.primaryColor)
                            Text(phrase.transliteration)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: { showAnswer = true }) {
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
                .padding()
            } else if showResult {
                VStack(spacing: 20) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Text("Time's Up!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Final Score: \(score)/\(phrases.count)")
                        .font(.title2)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            
            Spacer()
        }
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
