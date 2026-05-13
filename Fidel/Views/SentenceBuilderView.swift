import SwiftUI
import SwiftData

struct SentenceBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPattern: Pattern?
    @State private var currentSubstitutionIndex = 0
    @State private var selectedSubstitutions: [Pattern.Substitution] = []
    @State private var builtSentence = ""
    @State private var showSuccess = false
    @State private var score = 0
    
    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    
    var patterns: [Pattern] {
        lessonRepository.getPatterns().filter { !$0.substitutions.isEmpty }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if selectedPattern == nil {
                    patternSelectionView
                } else if let pattern = selectedPattern {
                    builderView(for: pattern)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Sentence Builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .toolbar {
            if selectedPattern != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Pattern") {
                        resetBuilder()
                    }
                }
            }
        }
        .alert("Great Job!", isPresented: $showSuccess) {
            Button("Build Another") {
                resetBuilder()
            }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("You earned 15 XP for building that sentence!")
        }
    }
    
    private var patternSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a Pattern")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select a sentence pattern to practice building sentences")
                .font(.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
            
            ForEach(patterns) { pattern in
                PatternSelectionCard(pattern: pattern) {
                    withAnimation {
                        selectedPattern = pattern
                        selectedSubstitutions = []
                        currentSubstitutionIndex = 0
                    }
                }
            }
        }
    }
    
    private func builderView(for pattern: Pattern) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(pattern.description)
                    .font(.headline)
                
                Text(pattern.category)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            
            VStack(spacing: 12) {
                Text("Pattern Structure")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                
                Text(pattern.structure)
                    .font(AppTheme.Typography.amharic(size: 24))
                    .foregroundStyle(AppTheme.primaryColor)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.primaryColor.opacity(0.1))
                    )
            }
            
            if !pattern.substitutions.isEmpty {
                substitutionSelector(for: pattern)
            }
            
            builtSentenceView(for: pattern)
            
            if !pattern.examples.isEmpty {
                examplesView(for: pattern)
            }
        }
    }
    
    private func substitutionSelector(for pattern: Pattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose words to substitute:")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(pattern.substitutions, id: \.amharic) { sub in
                    SubstitutionChip(
                        substitution: sub,
                        isSelected: selectedSubstitutions.contains { $0.amharic == sub.amharic }
                    ) {
                        toggleSubstitution(sub)
                    }
                }
            }
        }
    }
    
    private func builtSentenceView(for pattern: Pattern) -> some View {
        VStack(spacing: 12) {
            Text("Your Sentence")
                .font(.headline)
            
            if selectedSubstitutions.isEmpty {
                Text("Select words above to build your sentence")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundStyle(AppTheme.hairlineColor)
                    )
            } else {
                VStack(spacing: 8) {
                    let sentence = buildSentence(for: pattern)
                    
                    Text(sentence.amharic)
                        .font(AppTheme.Typography.amharic(size: 28))
                        .foregroundStyle(AppTheme.primaryColor)
                    
                    Text(sentence.transliteration)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    
                    Text(sentence.english)
                        .font(.body)
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.primaryColor.opacity(0.1))
                )
                
                Button(action: {
                    showSuccess = true
                    score += 15
                }) {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    
    private func examplesView(for pattern: Pattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example Sentences")
                .font(.headline)
            
            ForEach(pattern.examples.prefix(3), id: \.amharic) { example in
                VStack(alignment: .leading, spacing: 4) {
                    Text(example.amharic)
                        .font(AppTheme.Typography.amharic(size: 18))
                    Text(example.transliteration)
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    Text(example.english)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.infoColor)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.surfaceColor)
                )
            }
        }
    }
    
    private func toggleSubstitution(_ sub: Pattern.Substitution) {
        if let index = selectedSubstitutions.firstIndex(where: { $0.amharic == sub.amharic }) {
            selectedSubstitutions.remove(at: index)
        } else {
            if selectedSubstitutions.count < 1 {
                selectedSubstitutions.append(sub)
            } else {
                selectedSubstitutions[0] = sub
            }
        }
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    private func buildSentence(for pattern: Pattern) -> (amharic: String, transliteration: String, english: String) {
        guard let sub = selectedSubstitutions.first else {
            return ("", "", "")
        }
        
        var amharic = pattern.structure
        var english = pattern.description
        
        if amharic.contains("[adjective]") {
            amharic = amharic.replacingOccurrences(of: "[adjective]", with: sub.amharic)
            english = english.replacingOccurrences(of: "[adjective/state]", with: sub.english)
            english = english.replacingOccurrences(of: "[adjective]", with: sub.english)
        }
        if amharic.contains("[noun]") {
            amharic = amharic.replacingOccurrences(of: "[noun]", with: sub.amharic)
            english = english.replacingOccurrences(of: "[noun]", with: sub.english)
        }
        
        return (amharic, sub.transliteration, english)
    }
    
    private func resetBuilder() {
        selectedPattern = nil
        selectedSubstitutions = []
        currentSubstitutionIndex = 0
    }
}

struct PatternSelectionCard: View {
    let pattern: Pattern
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(pattern.description)
                    .font(.headline)
                    .foregroundStyle(AppTheme.inkColor)
                
                Text(pattern.structure)
                    .font(AppTheme.Typography.amharic(size: 18))
                    .foregroundStyle(AppTheme.primaryColor)
                
                HStack {
                    Label("\(pattern.substitutions.count) options", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
            .fidelSurface(.solid, padding: AppTheme.Spacing.md, cornerRadius: AppTheme.CornerRadius.medium)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pattern.description). \(pattern.structure). \(pattern.substitutions.count) options")
        .accessibilityHint("Starts this sentence pattern")
    }
}

struct SubstitutionChip: View {
    let substitution: Pattern.Substitution
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(substitution.amharic)
                    .font(AppTheme.Typography.amharic(size: 20))
                Text(substitution.english)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor)
            )
            .foregroundStyle(isSelected ? AppTheme.onAccentColor : AppTheme.inkColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(substitution.amharic), \(substitution.english)")
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

#Preview {
    NavigationStack {
        SentenceBuilderView()
    }
}
