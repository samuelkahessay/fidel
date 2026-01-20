import SwiftUI
import SwiftData

struct LearnView: View {
    @State private var selectedLesson: Lesson?
    @State private var showFidel = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    welcomeSection
                    fidelSection
                    lessonsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Learn Amharic")
            .sheet(isPresented: $showFidel) {
                FidelView()
            }
            .navigationDestination(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson)
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("እንኳን ደህና መጣህ!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppTheme.primaryColor)
            
            Text("Welcome to Amharic Learning")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Master the beautiful Ethiopian language through interactive lessons, conversations, and practice.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.label).opacity(0.08), radius: 10, y: 5)
        )
    }
    
    private var fidelSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fidel (ፊደል)")
                        .font(.headline)
                    Text("Learn the Ethiopic Script")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("ሀ ለ ሐ")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.primaryColor)
            }
            
            Button(action: { showFidel = true }) {
                HStack {
                    Image(systemName: "character.textbox")
                    Text("Explore the Alphabet")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primaryColor.opacity(0.1), AppTheme.secondaryColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lessons")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(AmharicData.lessons) { lesson in
                LessonCard(lesson: lesson)
                    .onTapGesture {
                        selectedLesson = lesson
                    }
            }
        }
    }
}

struct LessonCard: View {
    let lesson: Lesson
    @Query private var progressItems: [UserProgress]
    
    var isCompleted: Bool {
        progressItems.first?.lessonsCompleted.contains(lesson.id) ?? false
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCompleted ? AppTheme.primaryColor : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                
                Text(lesson.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(lesson.patterns.count) patterns", systemImage: "text.alignleft")
                    Label("\(lesson.vocabulary.count) words", systemImage: "textformat.abc")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.label).opacity(0.06), radius: 8, y: 4)
        )
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @Query private var progressItems: [UserProgress]
    @State private var currentSection = 0
    @State private var showCompletion = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
            .padding()
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Complete") {
                    completeLesson()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
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
        VStack(spacing: 16) {
            ForEach(lesson.patterns) { pattern in
                PatternCard(pattern: pattern)
            }
        }
    }
    
    private var vocabularySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(lesson.vocabulary) { word in
                VocabularyCard(word: word)
            }
        }
    }
    
    private var phrasesSection: some View {
        VStack(spacing: 12) {
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
    let pattern: Pattern
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.description)
                        .font(.headline)
                    
                    Text(pattern.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(pattern.structure)
                .font(.system(size: 22))
                .foregroundColor(AppTheme.primaryColor)
            
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examples:")
                        .font(.subheadline.bold())
                    
                    ForEach(pattern.examples, id: \.amharic) { example in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.amharic)
                                .font(.system(size: 20))
                            Text(example.transliteration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(example.english)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if !pattern.substitutions.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Substitutions:")
                            .font(.subheadline.bold())
                        
                        FlowLayout(spacing: 8) {
                            ForEach(pattern.substitutions, id: \.amharic) { sub in
                                VStack(spacing: 2) {
                                    Text(sub.amharic)
                                        .font(.system(size: 16))
                                    Text(sub.english)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.primaryColor.opacity(0.1))
                                )
                            }
                        }
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
}

struct VocabularyCard: View {
    let word: VocabularyWord
    
    var body: some View {
        VStack(spacing: 8) {
            Text(word.amharic)
                .font(.system(size: 24))
                .foregroundColor(AppTheme.primaryColor)
            
            Text(word.transliteration)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(word.english)
                .font(.subheadline)
                .fontWeight(.medium)
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

struct PhraseRow: View {
    let phrase: Phrase
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.amharic)
                    .font(.system(size: 20))
                Text(phrase.transliteration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(phrase.english)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !phrase.notes.isEmpty {
                    Text(phrase.notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.04), radius: 4, y: 2)
        )
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
