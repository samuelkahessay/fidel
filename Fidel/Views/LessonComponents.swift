import SwiftUI
import SwiftData
import SyncKit

struct LessonCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    let lesson: Lesson

    var isCompleted: Bool {
        let progressRepository = ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
        return progressRepository.getUserProgress()?.lessonsCompleted.contains(lesson.id) ?? false
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(isCompleted ? AppTheme.primaryColor : AppTheme.inkColor.opacity(0.08))
                    .frame(width: 52, height: 52)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.onAccentColor)
                        .font(.title3.bold())
                } else {
                    Text("\(lesson.id)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primaryColor)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(lesson.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)

                Text(lesson.description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .lineLimit(2)

                HStack(spacing: AppTheme.Spacing.sm) {
                    StatPill(icon: "text.alignleft", value: "\(lesson.patterns.count)", color: AppTheme.infoColor)
                    StatPill(icon: "textformat.abc", value: "\(lesson.vocabulary.count)", color: AppTheme.successColor)
                }
                .padding(.top, AppTheme.Spacing.xxs)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .glassCard()
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    @State private var currentSection = 0
    @State private var showCompletion = false
    @State private var showSelam = false
    @State private var bundledAudio = BundledAudioService()
    @State private var ttsAudio = AudioService()

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
                case 3:
                    cultureSection
                default:
                    EmptyView()
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.groupedBackground)
        .onAppear {
            ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
                .markLessonStarted(lesson.id)
        }
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
                .secondaryGlassButton()
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

    private var culturalNotes: [CulturalNote] {
        LessonRepository.shared.getCulturalNotes(forLesson: lesson.id)
    }

    private var sectionPicker: some View {
        Picker("Section", selection: $currentSection) {
            Text("Patterns").tag(0)
            Text("Vocabulary").tag(1)
            Text("Phrases").tag(2)
            if !culturalNotes.isEmpty {
                Text("Culture").tag(3)
            }
        }
        .pickerStyle(.segmented)
    }

    private var patternsSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(lesson.patterns) { pattern in
                PatternCard(pattern: pattern, bundled: bundledAudio, tts: ttsAudio)
            }
        }
    }

    private var vocabularySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
            ForEach(lesson.vocabulary) { word in
                VocabularyCard(word: word, bundled: bundledAudio, tts: ttsAudio)
            }
        }
    }

    private var phrasesSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(lesson.phrases) { phrase in
                PhraseRow(phrase: phrase, bundled: bundledAudio, tts: ttsAudio)
            }
        }
    }

    private var cultureSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(culturalNotes) { note in
                CulturalNoteCard(note: note)
            }
        }
    }

    private func completeLesson() {
        let progressRepository = ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) })
        progressRepository.completeLesson(lesson.id)
        showCompletion = true
    }
}

struct PatternCard: View {
    @Environment(\.colorScheme) var colorScheme
    let pattern: Pattern
    var bundled: BundledAudioService
    var tts: AudioService
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(pattern.description)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.inkColor)

                    Text(pattern.category)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }

                Spacer()

                Button(action: {
                    withAnimation(AppTheme.Animation.standard) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppTheme.inkColor.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }

            Text(pattern.structure)
                .font(AppTheme.Typography.amharic(size: 24))
                .foregroundStyle(AppTheme.primaryColor)
                .padding(.vertical, AppTheme.Spacing.xxs)

            if isExpanded {
                Divider()
                    .padding(.vertical, AppTheme.Spacing.xs)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Examples")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.inkSecondaryColor)

                    ForEach(pattern.examples, id: \.amharic) { example in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                Text(example.amharic)
                                    .font(AppTheme.Typography.amharic(size: 20))
                                    .foregroundStyle(AppTheme.inkColor)
                                Text(example.transliteration)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.inkSecondaryColor)
                                Text(example.english)
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundStyle(AppTheme.primaryColor)
                            }

                            Spacer(minLength: 0)

                            PronunciationButton(
                                content: .dynamic(amharic: example.amharic, transliteration: example.transliteration),
                                bundled: bundled,
                                tts: tts
                            )
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
                            .foregroundStyle(AppTheme.inkSecondaryColor)

                        FlowLayout(spacing: AppTheme.Spacing.xs) {
                            ForEach(pattern.substitutions, id: \.amharic) { sub in
                                VStack(spacing: 2) {
                                    Text(sub.amharic)
                                        .font(AppTheme.Typography.amharic(size: 16))
                                        .foregroundStyle(AppTheme.inkColor)
                                    Text(sub.english)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.inkSecondaryColor)
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
    var bundled: BundledAudioService
    var tts: AudioService

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(word.amharic)
                .font(AppTheme.Typography.amharic(size: 26))
                .foregroundStyle(AppTheme.primaryColor)

            Text(word.transliteration)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)

            Text(word.english)
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.inkColor)

            PronunciationButton(content: .vocabulary(word), bundled: bundled, tts: tts)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

struct PhraseRow: View {
    let phrase: Phrase
    var bundled: BundledAudioService
    var tts: AudioService

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(phrase.amharic)
                    .font(AppTheme.Typography.amharic(size: 20))
                    .foregroundStyle(AppTheme.inkColor)
                Text(phrase.transliteration)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            PronunciationButton(content: .phrase(phrase), bundled: bundled, tts: tts)

            Spacer()

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                Text(phrase.english)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.inkColor)
                if !phrase.notes.isEmpty {
                    Text(phrase.notes)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
        }
        .glassCard(padding: AppTheme.Spacing.sm)
    }
}

struct CulturalNoteCard: View {
    let note: CulturalNote
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Button(action: {
                withAnimation(AppTheme.Animation.standard) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: note.icon)
                        .font(.title2)
                        .foregroundStyle(AppTheme.secondaryColor)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(AppTheme.secondaryColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(note.title)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.inkColor)

                        Text(note.amharicTitle)
                            .font(AppTheme.Typography.amharic(size: 16))
                            .foregroundStyle(AppTheme.inkSecondaryColor)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppTheme.inkColor.opacity(0.05)))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.vertical, AppTheme.Spacing.xxs)

                Text(note.content)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.inkColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard()
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
