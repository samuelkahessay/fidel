import SwiftUI
import SwiftData

enum QuizMode: String, CaseIterable {
    case mixed = "Mixed"
    case multipleChoice = "Multiple Choice"
    case typeTranslation = "Type Translation"
    case typeTransliteration = "Type Pronunciation"
}

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    
    @State private var quizMode: QuizMode = .mixed
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex = 0
    @State private var selectedAnswer: String?
    @State private var typedAnswer: String = ""
    @State private var showResult = false
    @State private var score = 0
    @State private var showFeedback = false
    @State private var isCorrect = false
    @FocusState private var isTextFieldFocused: Bool
    
    var currentQuestion: QuizQuestion? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if questions.isEmpty {
                    modeSelectionView
                } else if let question = currentQuestion, !showResult {
                    quizContent(question: question)
                } else if showResult {
                    resultsView
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
    }
    
    private var modeSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Quiz Type")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(QuizMode.allCases, id: \.self) { mode in
                    Button(action: {
                        quizMode = mode
                        generateQuestions()
                    }) {
                        HStack {
                            Image(systemName: iconForMode(mode))
                                .font(.title2)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.rawValue)
                                    .font(.headline)
                                Text(descriptionForMode(mode))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .fidelSurface(.solid, padding: AppTheme.Spacing.md, cornerRadius: AppTheme.CornerRadius.medium)
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                    }
                    .foregroundStyle(.primary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(mode.rawValue). \(descriptionForMode(mode))")
                    .accessibilityHint("Starts this quiz type")
                }
            }
        }
    }
    
    private func iconForMode(_ mode: QuizMode) -> String {
        switch mode {
        case .mixed: return "shuffle"
        case .multipleChoice: return "list.bullet"
        case .typeTranslation: return "character.cursor.ibeam"
        case .typeTransliteration: return "textformat.abc"
        }
    }
    
    private func descriptionForMode(_ mode: QuizMode) -> String {
        switch mode {
        case .mixed: return "All question types combined"
        case .multipleChoice: return "Tap the correct answer"
        case .typeTranslation: return "Type the English meaning"
        case .typeTransliteration: return "Type how it's pronounced"
        }
    }
    
    private func quizContent(question: QuizQuestion) -> some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(currentIndex), total: Double(questions.count))
                .tint(AppTheme.primaryColor)
                .accessibilityLabel("Quiz progress")
                .accessibilityValue("Question \(currentIndex + 1) of \(questions.count)")
            
            HStack {
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Score: \(score)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryColor)
            }
            
            questionCard(question: question)
            
            if question.type == .multipleChoice {
                multipleChoiceOptions(question: question)
            } else {
                typingInput(question: question)
            }
            
            if showFeedback {
                feedbackView(question: question)
            }
            
        }
    }
    
    private func questionCard(question: QuizQuestion) -> some View {
        VStack(spacing: 16) {
            Text(question.question)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let amharic = question.amharic {
                Text(amharic)
                    .font(AppTheme.Typography.amharic(size: 36))
                    .foregroundStyle(AppTheme.primaryColor)
            }
            
            if question.type == .listening, let hint = question.transliterationHint {
                Text("Hint: \(hint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.primaryColor.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
    }
    
    private func multipleChoiceOptions(question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options, id: \.self) { option in
                AnswerButton(
                    option: option,
                    isSelected: selectedAnswer == option,
                    isCorrect: showFeedback && option == question.correctAnswer,
                    isWrong: showFeedback && selectedAnswer == option && option != question.correctAnswer
                ) {
                    selectAnswer(option, for: question)
                }
            }
        }
    }
    
    private func typingInput(question: QuizQuestion) -> some View {
        VStack(spacing: 16) {
            TextField(placeholderForQuestion(question), text: $typedAnswer)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isTextFieldFocused)
                .disabled(showFeedback)
                .onSubmit {
                    if !showFeedback {
                        submitTypedAnswer(for: question)
                    }
                }
            
            if !showFeedback {
                Button(action: {
                    submitTypedAnswer(for: question)
                }) {
                    Text("Check Answer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(typedAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private func placeholderForQuestion(_ question: QuizQuestion) -> String {
        switch question.type {
        case .translation: return "Type the English translation..."
        case .listening: return "Type what you hear..."
        default: return "Type your answer..."
        }
    }
    
    private func feedbackView(question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isCorrect ? AppTheme.successColor : AppTheme.accentRed)
                
                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(.headline)
                    .foregroundStyle(isCorrect ? AppTheme.successColor : AppTheme.accentRed)
            }
            
            if !isCorrect {
                VStack(spacing: 4) {
                    Text("Correct answer:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(question.correctAnswer)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryColor)
                }
            }
            
            Button(action: nextQuestion) {
                Text(currentIndex < questions.count - 1 ? "Next Question" : "See Results")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCorrect ? AppTheme.successColor.opacity(0.1) : AppTheme.accentRed.opacity(0.1))
        )
        .accessibilityElement(children: .contain)
    }
    
    private var resultsView: some View {
        VStack(spacing: 24) {
            Image(systemName: score >= questions.count / 2 ? "trophy.fill" : "arrow.counterclockwise")
                .font(.system(size: 60))
                .foregroundStyle(score >= questions.count / 2 ? AppTheme.secondaryColor : AppTheme.warningColor)
            
            Text("Quiz Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("\(score)/\(questions.count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(AppTheme.primaryColor)
                
                let percentage = questions.count > 0 ? Int((Double(score) / Double(questions.count)) * 100) : 0
                Text("\(percentage)% Correct")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            XPBadge(xp: score * 10)
            
            VStack(spacing: 12) {
                Button(action: resetQuiz) {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button(action: { dismiss() }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
    
    private func generateQuestions() {
        var generatedQuestions: [QuizQuestion] = []
        let allVocab = lessonRepository.getVocabulary()
        let shuffledVocab = Array(allVocab.shuffled().prefix(12))
        
        for (index, word) in shuffledVocab.enumerated() {
            let questionType: QuizType
            
            switch quizMode {
            case .multipleChoice:
                questionType = .multipleChoice
            case .typeTranslation:
                questionType = .translation
            case .typeTransliteration:
                questionType = .listening
            case .mixed:
                let types: [QuizType] = [.multipleChoice, .translation, .listening]
                questionType = types[index % types.count]
            }
            
            let question: QuizQuestion
            
            switch questionType {
            case .multipleChoice:
                let wrongAnswers = allVocab
                    .filter { $0.english != word.english }
                    .shuffled()
                    .prefix(3)
                    .map { $0.english }
                let options = ([word.english] + wrongAnswers).shuffled()
                
                question = QuizQuestion(
                    type: .multipleChoice,
                    question: "What does this word mean?",
                    amharic: word.amharic,
                    correctAnswer: word.english,
                    options: options,
                    transliterationHint: nil
                )
                
            case .translation:
                question = QuizQuestion(
                    type: .translation,
                    question: "Type the English meaning:",
                    amharic: word.amharic,
                    correctAnswer: word.english,
                    options: [],
                    transliterationHint: nil
                )
                
            case .listening:
                let hint = String(word.transliteration.prefix(2)) + "..."
                question = QuizQuestion(
                    type: .listening,
                    question: "How is this word pronounced? (Type in English letters)",
                    amharic: word.amharic,
                    correctAnswer: word.transliteration.lowercased(),
                    options: [],
                    transliterationHint: hint
                )
                
            default:
                continue
            }
            
            generatedQuestions.append(question)
        }
        
        questions = generatedQuestions.shuffled()
        isTextFieldFocused = questions.first?.type != .multipleChoice
    }
    
    private func selectAnswer(_ answer: String, for question: QuizQuestion) {
        guard selectedAnswer == nil else { return }
        
        selectedAnswer = answer
        isCorrect = answer.lowercased() == question.correctAnswer.lowercased()
        
        if isCorrect { score += 1 }
        
        let feedback = UIImpactFeedbackGenerator(style: isCorrect ? .medium : .heavy)
        feedback.impactOccurred()
        
        withAnimation { showFeedback = true }
    }
    
    private func submitTypedAnswer(for question: QuizQuestion) {
        let trimmedAnswer = typedAnswer.trimmingCharacters(in: .whitespaces).lowercased()
        let correctAnswer = question.correctAnswer.lowercased()
        
        isCorrect = trimmedAnswer == correctAnswer || isCloseEnough(trimmedAnswer, to: correctAnswer)
        
        if isCorrect { score += 1 }
        
        let feedback = UIImpactFeedbackGenerator(style: isCorrect ? .medium : .heavy)
        feedback.impactOccurred()
        
        withAnimation { showFeedback = true }
        isTextFieldFocused = false
    }
    
    private func isCloseEnough(_ answer: String, to correct: String) -> Bool {
        if answer == correct { return true }
        
        let distance = levenshteinDistance(answer, correct)
        let threshold = max(1, correct.count / 4)
        return distance <= threshold
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
    
    private func nextQuestion() {
        selectedAnswer = nil
        typedAnswer = ""
        showFeedback = false
        
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            if let question = currentQuestion {
                isTextFieldFocused = question.type != .multipleChoice
            }
        } else {
            showResult = true
            let progressRepository = ProgressRepository(modelContext: modelContext)
            progressRepository.addXP(score * 10)
        }
    }
    
    private func resetQuiz() {
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        typedAnswer = ""
        showFeedback = false
        showResult = false
        questions = []
    }
}

struct AnswerButton: View {
    let option: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let action: () -> Void
    
    var backgroundColor: Color {
        if isCorrect { return AppTheme.successColor.opacity(0.2) }
        if isWrong { return AppTheme.accentRed.opacity(0.2) }
        if isSelected { return AppTheme.primaryColor.opacity(0.2) }
        return AppTheme.surfaceColor
    }
    
    var borderColor: Color {
        if isCorrect { return AppTheme.successColor }
        if isWrong { return AppTheme.accentRed }
        if isSelected { return AppTheme.primaryColor }
        return .clear
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.successColor)
                } else if isWrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.accentRed)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 2)
                    )
            )
        }
        .disabled(isCorrect || isWrong)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(option)
        .accessibilityValue(isCorrect ? "Correct answer" : (isWrong ? "Incorrect answer" : (isSelected ? "Selected" : "")))
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
    .modelContainer(for: [UserProgress.self], inMemory: true)
}
