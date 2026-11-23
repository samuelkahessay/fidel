import SwiftUI

/// Reading: a list of graded passages. Comprehensible-input reading with
/// per-sentence transliteration + gloss, a glossary, and comprehension questions.
struct ReadingView: View {
    @State private var viewModel = ReadingViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("Read short Amharic passages, then check your understanding.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.passages) { passage in
                    NavigationLink {
                        ReadingPassageView(passage: passage)
                    } label: {
                        passageCard(passage)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
    }

    private func passageCard(_ passage: ReadingPassage) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(passage.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                Text("\(passage.sentences.count) sentences · \(passage.questions.count) questions")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            Spacer(minLength: 0)
            Text(passage.cefr)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, 4)
                .background(AppTheme.infoColor.opacity(0.15), in: Capsule())
                .foregroundStyle(AppTheme.infoColor)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large).fill(AppTheme.cardColor))
        .accessibilityElement(children: .combine)
    }
}

/// One passage: the text (Amharic / transliteration / English per sentence), a
/// glossary, and tap-to-answer comprehension questions with a score.
struct ReadingPassageView: View {
    let passage: ReadingPassage

    @State private var audio = WordAudioPlayer()
    @State private var answers: [Int: Int] = [:]  // questionIndex -> chosen optionIndex

    private var score: Int {
        passage.questions.indices.reduce(0) { acc, i in
            acc + (answers[i] == passage.questions[i].answerIndex ? 1 : 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                passageText
                if !passage.glossary.isEmpty { glossarySection }
                if !passage.questions.isEmpty { questionsSection }
            }
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle(passage.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
    }

    private var passageText: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            ForEach(Array(passage.sentences.enumerated()), id: \.offset) { _, s in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                        Text(s.amharic)
                            .font(AppTheme.Typography.amharic(size: 22))
                            .foregroundStyle(AppTheme.inkColor)
                        Button {
                            audio.play(s.amharic)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.primaryColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play pronunciation")
                    }
                    Text(s.transliteration)
                        .font(AppTheme.Typography.transliteration(size: 13))
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    Text(s.english)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large).fill(AppTheme.cardColor))
    }

    private var glossarySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Glossary")
                .font(AppTheme.Typography.caption).textCase(.uppercase)
                .foregroundStyle(AppTheme.inkSecondaryColor)
            ForEach(Array(passage.glossary.enumerated()), id: \.offset) { _, g in
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(g.amharic).font(AppTheme.Typography.amharic(size: 18)).foregroundStyle(AppTheme.primaryColor)
                    Text("—").foregroundStyle(AppTheme.mutedInkColor)
                    Text(g.english).font(AppTheme.Typography.subheadline).foregroundStyle(AppTheme.inkColor)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large).fill(AppTheme.primaryColor.opacity(0.06)))
    }

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Text("Comprehension").font(AppTheme.Typography.headline)
                Spacer()
                Text("Score: \(score)/\(passage.questions.count)")
                    .font(AppTheme.Typography.subheadline).foregroundStyle(AppTheme.primaryColor)
            }
            ForEach(Array(passage.questions.enumerated()), id: \.offset) { qi, q in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(q.question).font(AppTheme.Typography.body).foregroundStyle(AppTheme.inkColor)
                    ForEach(Array(q.options.enumerated()), id: \.offset) { oi, option in
                        optionRow(qi: qi, oi: oi, option: option, answerIndex: q.answerIndex)
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large).fill(AppTheme.cardColor))
            }
        }
    }

    private func optionRow(qi: Int, oi: Int, option: String, answerIndex: Int) -> some View {
        let chosen = answers[qi]
        let answered = chosen != nil
        let isCorrect = oi == answerIndex
        let isChosen = chosen == oi
        return Button {
            if answers[qi] == nil { answers[qi] = oi }
        } label: {
            HStack {
                Text(option).font(AppTheme.Typography.subheadline).foregroundStyle(AppTheme.inkColor)
                Spacer(minLength: 0)
                if answered && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.successColor)
                } else if answered && isChosen {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.accentRed)
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(rowFill(answered: answered, isCorrect: isCorrect, isChosen: isChosen))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium).stroke(AppTheme.hairlineColor))
            )
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    private func rowFill(answered: Bool, isCorrect: Bool, isChosen: Bool) -> Color {
        guard answered else { return AppTheme.groupedBackground }
        if isCorrect { return AppTheme.successColor.opacity(0.15) }
        if isChosen { return AppTheme.accentRed.opacity(0.12) }
        return AppTheme.groupedBackground
    }
}

#Preview {
    NavigationStack { ReadingView() }
}
