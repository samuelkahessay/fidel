import SwiftUI
import SwiftData

struct LearnView: View {
    @State private var viewModel = LearnViewModel()
    @State private var showFidel = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    welcomeSection
                    fidelSection
                    lessonsSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Learn Amharic")
            .sheet(isPresented: $showFidel) {
                FidelView()
            }
            .navigationDestination(item: $viewModel.selectedLesson) { lesson in
                LessonDetailView(lesson: lesson)
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("እንኳን ደህና መጣህ!")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(AppTheme.primaryColor)
            
            Text("Welcome to Amharic Learning")
                .font(AppTheme.Typography.title3)
                .foregroundColor(.secondary)
            
            Text("Master the beautiful Ethiopian language through interactive lessons, conversations, and practice.")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, AppTheme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedGlassCard(tint: AppTheme.primaryColor, tintOpacity: 0.05)
    }
    
    private var fidelSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Fidel (ፊደል)")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.primary)
                    Text("Learn the Ethiopic Script")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("ሀ ለ ሐ")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppTheme.primaryColor)
            }
            
            Button(action: { showFidel = true }) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "character.textbox")
                    Text("Explore the Alphabet")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .tintedGlassCard(tint: AppTheme.secondaryColor, tintOpacity: 0.06)
    }
    
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Lessons")
                .font(AppTheme.Typography.title2)
                .foregroundColor(.primary)
            
            ForEach(viewModel.lessons) { lesson in
                LessonCard(lesson: lesson)
                    .onTapGesture {
                        viewModel.selectLesson(lesson)
                    }
            }
        }
    }
}

struct LessonCard: View {
    @Environment(\.colorScheme) var colorScheme
    let lesson: Lesson
    @Query private var progressItems: [UserProgress]
    
    var isCompleted: Bool {
        progressItems.first?.lessonsCompleted.contains(lesson.id) ?? false
    }
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(isCompleted ? AppTheme.primaryColor : Color.primary.opacity(0.08))
                    .frame(width: 52, height: 52)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.title3.bold())
                } else {
                    Text("\(lesson.id)")
                        .font(.title2.bold())
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(lesson.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.primary)
                
                Text(lesson.description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: AppTheme.Spacing.sm) {
                    StatPill(icon: "text.alignleft", value: "\(lesson.patterns.count)", color: .blue)
                    StatPill(icon: "textformat.abc", value: "\(lesson.vocabulary.count)", color: .green)
                }
                .padding(.top, AppTheme.Spacing.xxs)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .glassCard()
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @Query private var progressItems: [UserProgress]
    @State private var currentSection = 0
    @State private var showCompletion = false
    @State private var showSelam = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                sectionPicker
                
                switch currentSection {
                case 0:
                    patternsSection
                case 1:
                    vocabularySection
                case 2:
                    phrasesSection
                default:
                    EmptyView()
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showSelam = true }) {
                    Image(systemName: "sparkles")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Complete") {
                    completeLesson()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sheet(isPresented: $showSelam) {
            SelamContextSheet(
                entryContext: SelamEntryContext(
                    type: SelamEntryContext.EntryContextType.lesson,
                    itemId: String(lesson.id),
                    itemTitle: lesson.title,
                    additionalContext: nil
                )
            )
        }
        .alert("Lesson Complete!", isPresented: $showCompletion) {
            Button("OK") { }
        } message: {
            Text("You earned 25 XP!")
        }
    }
    
    private var sectionPicker: some View {
        Picker("Section", selection: $currentSection) {
            Text("Patterns").tag(0)
            Text("Vocabulary").tag(1)
            Text("Phrases").tag(2)
        }
        .pickerStyle(.segmented)
    }
    
    private var patternsSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(lesson.patterns) { pattern in
                PatternCard(pattern: pattern)
            }
        }
    }
    
    private var vocabularySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
            ForEach(lesson.vocabulary) { word in
                VocabularyCard(word: word)
            }
        }
    }
    
    private var phrasesSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(lesson.phrases) { phrase in
                PhraseRow(phrase: phrase)
            }
        }
    }
    
    private func completeLesson() {
        if let progress = progressItems.first {
            progress.completeLesson(lesson.id)
            showCompletion = true
        }
    }
}

struct PatternCard: View {
    @Environment(\.colorScheme) var colorScheme
    let pattern: Pattern
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(pattern.description)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text(pattern.category)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(AppTheme.Animation.standard) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
            
            Text(pattern.structure)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(AppTheme.primaryColor)
                .padding(.vertical, AppTheme.Spacing.xxs)
            
            if isExpanded {
                Divider()
                    .padding(.vertical, AppTheme.Spacing.xs)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Examples")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(pattern.examples, id: \.amharic) { example in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(example.amharic)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                            Text(example.transliteration)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(.secondary)
                            Text(example.english)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.primaryColor)
                        }
                        .padding(.vertical, AppTheme.Spacing.xxs)
                    }
                }
                
                if !pattern.substitutions.isEmpty {
                    Divider()
                        .padding(.vertical, AppTheme.Spacing.xs)
                    
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Substitutions")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: AppTheme.Spacing.xs) {
                            ForEach(pattern.substitutions, id: \.amharic) { sub in
                                VStack(spacing: 2) {
                                    Text(sub.amharic)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(sub.english)
                                        .font(AppTheme.Typography.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                                        .fill(AppTheme.primaryColor.opacity(0.08))
                                )
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }
}

struct VocabularyCard: View {
    let word: VocabularyWord
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(word.amharic)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(AppTheme.primaryColor)
            
            Text(word.transliteration)
                .font(AppTheme.Typography.caption)
                .foregroundColor(.secondary)
            
            Text(word.english)
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

struct PhraseRow: View {
    let phrase: Phrase
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(phrase.amharic)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                Text(phrase.transliteration)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                Text(phrase.english)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                if !phrase.notes.isEmpty {
                    Text(phrase.notes)
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .glassCard(padding: AppTheme.Spacing.sm)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            height = y + rowHeight
        }
    }
}

#Preview {
    LearnView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
