import SwiftData
import SwiftUI
import SyncKit

/// Cloze ("fill in the blank") exercise. An Amharic sentence is shown with one
/// word removed and the English translation for context; the learner picks the
/// missing word from options. Tapping an option plays its pronunciation. Builds
/// vocabulary and grammar *in context* rather than in isolation.
struct ClozeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = ClozeViewModel()
    @State private var audio = WordAudioPlayer()
    @State private var didSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                if viewModel.showResult {
                    resultsView
                } else if let question = viewModel.currentQuestion {
                    questionContent(question)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Fill the Blank")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .onAppear(perform: setup)
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        viewModel.configure(progressRepository: ProgressRepository(modelContext: modelContext, onMutation: { sync.markPending($0) }))
        viewModel.startSession()
    }

    // MARK: - Question

    private func questionContent(_ question: ClozeViewModel.Question) -> some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            progressHeader

            promptCard(question)

            Text("Tap the missing word")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            optionsZone(question)

            if viewModel.showFeedback {
                feedbackView(question)
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ProgressView(
                value: Double(viewModel.currentIndex),
                total: Double(max(viewModel.questions.count, 1))
            )
            .tint(AppTheme.primaryColor)
            .accessibilityLabel("Exercise progress")
            .accessibilityValue("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")

            HStack {
                Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                Spacer()
                Text("Score: \(viewModel.score)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.primaryColor)
            }
        }
    }

    private func promptCard(_ question: ClozeViewModel.Question) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text(question.english)
                .font(AppTheme.Typography.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.inkColor)

            sentenceWithBlank(question)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.primaryColor.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    /// The Amharic sentence, with the missing word shown as a blank slot that
    /// fills in (colored by correctness) once an answer is chosen.
    private func sentenceWithBlank(_ question: ClozeViewModel.Question) -> some View {
        FlowLayout(spacing: AppTheme.Spacing.xs) {
            ForEach(question.segments) { segment in
                if segment.isBlank {
                    blankSlot
                } else {
                    Text(segment.text)
                        .font(AppTheme.Typography.amharic(size: 30))
                        .foregroundStyle(AppTheme.primaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var blankSlot: some View {
        Group {
            if viewModel.showFeedback, let chosen = viewModel.selectedOption {
                Text(chosen.amharic)
                    .font(AppTheme.Typography.amharic(size: 30))
                    .foregroundStyle(viewModel.lastWasCorrect ? AppTheme.successColor : AppTheme.accentRed)
            } else {
                Text("＿＿")
                    .font(AppTheme.Typography.amharic(size: 30))
                    .foregroundStyle(AppTheme.mutedInkColor)
            }
        }
    }

    // MARK: - Options

    private func optionsZone(_ question: ClozeViewModel.Question) -> some View {
        FlowLayout(spacing: AppTheme.Spacing.sm) {
            ForEach(question.options) { option in
                optionButton(option, question: question)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func optionButton(_ option: ClozeViewModel.Option, question: ClozeViewModel.Question) -> some View {
        Button {
            onOptionTap(option)
        } label: {
            VStack(spacing: 2) {
                Text(option.amharic)
                    .font(AppTheme.Typography.amharic(size: 24))
                    .foregroundStyle(AppTheme.inkColor)
                if let transliteration = option.transliteration {
                    Text(transliteration)
                        .font(AppTheme.Typography.transliteration(size: 11))
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(optionFill(option, question: question))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(optionBorder(option, question: question), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.showFeedback)
        .accessibilityLabel(option.amharic)
        .accessibilityHint("Plays pronunciation and selects the word")
    }

    /// After grading, tint the correct option green and an incorrect chosen option red.
    private func optionFill(_ option: ClozeViewModel.Option, question: ClozeViewModel.Question) -> Color {
        guard viewModel.showFeedback else { return AppTheme.cardColor }
        if option.amharic == question.correctAnswer { return AppTheme.successColor.opacity(0.18) }
        if option == viewModel.selectedOption { return AppTheme.accentRed.opacity(0.15) }
        return AppTheme.cardColor
    }

    private func optionBorder(_ option: ClozeViewModel.Option, question: ClozeViewModel.Question) -> Color {
        guard viewModel.showFeedback else { return AppTheme.hairlineColor }
        if option.amharic == question.correctAnswer { return AppTheme.successColor }
        if option == viewModel.selectedOption { return AppTheme.accentRed }
        return AppTheme.hairlineColor
    }

    // MARK: - Feedback

    private func feedbackView(_ question: ClozeViewModel.Question) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: viewModel.lastWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.lastWasCorrect ? AppTheme.successColor : AppTheme.accentRed)
                Text(viewModel.lastWasCorrect ? "Correct!" : "Not quite")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(viewModel.lastWasCorrect ? AppTheme.successColor : AppTheme.accentRed)
            }

            VStack(spacing: AppTheme.Spacing.xxs) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(question.fullAmharic)
                        .font(AppTheme.Typography.amharic(size: 24))
                        .foregroundStyle(AppTheme.primaryColor)
                        .multilineTextAlignment(.center)
                    Button {
                        audio.play(question.fullAmharic)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primaryColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play sentence pronunciation")
                }
                Text(question.fullTransliteration)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            Button(action: advance) {
                Text(viewModel.isLastQuestion ? "See Results" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .primaryGlassButton(fullWidth: true)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill((viewModel.lastWasCorrect ? AppTheme.successColor : AppTheme.accentRed).opacity(0.1))
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: viewModel.score >= viewModel.questions.count / 2 ? "trophy.fill" : "arrow.counterclockwise")
                .font(.system(size: 60))
                .foregroundStyle(viewModel.score >= viewModel.questions.count / 2 ? AppTheme.secondaryColor : AppTheme.warningColor)

            Text("Exercise Complete!")
                .font(AppTheme.Typography.title)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(viewModel.score)/\(viewModel.questions.count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(AppTheme.primaryColor)
                let percentage = viewModel.questions.isEmpty ? 0 : Int((Double(viewModel.score) / Double(viewModel.questions.count)) * 100)
                Text("\(percentage)% correct")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            XPBadge(xp: viewModel.earnedXP)

            VStack(spacing: AppTheme.Spacing.sm) {
                Button(action: { viewModel.restart() }) {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .primaryGlassButton(fullWidth: true)

                Button(action: { dismiss() }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .secondaryGlassButton(fullWidth: true)
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Actions

    private func onOptionTap(_ option: ClozeViewModel.Option) {
        audio.play(option.amharic)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(reduceMotion ? nil : AppTheme.Animation.quick) {
            viewModel.select(option)
        }
        let result = UIImpactFeedbackGenerator(style: viewModel.lastWasCorrect ? .medium : .heavy)
        result.impactOccurred()
    }

    private func advance() {
        withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
            viewModel.advance()
        }
    }
}

#Preview {
    NavigationStack {
        ClozeView()
    }
    .modelContainer(for: [UserProgress.self, FlashcardProgress.self], inMemory: true)
}
