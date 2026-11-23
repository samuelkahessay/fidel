import SwiftData
import SwiftUI
import SyncKit

/// Duolingo-style "translate this sentence" exercise. The learner taps shuffled
/// word tiles into the correct order — building the Amharic sentence from an
/// English prompt, or the English sentence from an Amharic prompt. Tapping an
/// Amharic tile plays its pronunciation.
struct WordOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var sync
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = WordOrderViewModel()
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
        .navigationTitle("Word Order")
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

    private func questionContent(_ question: WordOrderViewModel.Question) -> some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            progressHeader

            promptCard(question)

            Text(question.tilesAreAmharic ? "Tap the Amharic words in order" : "Tap the English words in order")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            answerZone(question)
            wordBank(question)

            if viewModel.showFeedback {
                feedbackView(question)
            } else {
                Button(action: check) {
                    Text("Check")
                        .frame(maxWidth: .infinity)
                }
                .primaryGlassButton(fullWidth: true)
                .disabled(!viewModel.canCheck)
                .opacity(viewModel.canCheck ? 1 : 0.5)
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

    private func promptCard(_ question: WordOrderViewModel.Question) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Translate this sentence")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .textCase(.uppercase)

            if question.tilesAreAmharic {
                Text(question.promptText)
                    .font(AppTheme.Typography.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.inkColor)
            } else {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(question.promptText)
                        .font(AppTheme.Typography.amharic(size: 30))
                        .foregroundStyle(AppTheme.primaryColor)
                    if let audioText = question.promptAudioText {
                        Button {
                            audio.play(audioText)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.primaryColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play pronunciation")
                    }
                }
                .multilineTextAlignment(.center)

                if let transliteration = question.promptTransliteration {
                    Text(transliteration)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.primaryColor.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Answer & bank

    private func answerZone(_ question: WordOrderViewModel.Question) -> some View {
        FlowLayout(spacing: AppTheme.Spacing.xs) {
            ForEach(viewModel.placed) { tile in
                WordTileButton(
                    text: tile.text,
                    transliteration: tile.transliteration,
                    isAmharic: tile.isAmharic,
                    isPlaced: true,
                    isSpeaking: audio.isSpeaking(tile.text)
                ) {
                    onTilePlacedTap(tile)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(
                    style: StrokeStyle(lineWidth: 1.5, dash: viewModel.placed.isEmpty ? [5] : [])
                )
                .foregroundStyle(AppTheme.hairlineColor)
        )
        .overlay(alignment: .leading) {
            if viewModel.placed.isEmpty {
                Text("Tap words below to build your answer")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.mutedInkColor)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .allowsHitTesting(false)
            }
        }
    }

    private func wordBank(_ question: WordOrderViewModel.Question) -> some View {
        FlowLayout(spacing: AppTheme.Spacing.xs) {
            ForEach(viewModel.bank) { tile in
                WordTileButton(
                    text: tile.text,
                    transliteration: tile.transliteration,
                    isAmharic: tile.isAmharic,
                    isPlaced: false,
                    isSpeaking: audio.isSpeaking(tile.text)
                ) {
                    onTileBankTap(tile)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func feedbackView(_ question: WordOrderViewModel.Question) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: viewModel.lastWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.lastWasCorrect ? AppTheme.successColor : AppTheme.accentRed)
                Text(viewModel.lastWasCorrect ? "Correct!" : "Not quite")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(viewModel.lastWasCorrect ? AppTheme.successColor : AppTheme.accentRed)
            }

            if !viewModel.lastWasCorrect {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("Answer")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    Text(question.correctText)
                        .font(question.tilesAreAmharic ? AppTheme.Typography.amharic(size: 22) : AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.primaryColor)
                        .multilineTextAlignment(.center)
                }
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

    private func onTileBankTap(_ tile: WordOrderViewModel.Tile) {
        playIfAmharic(tile)
        withAnimation(reduceMotion ? nil : AppTheme.Animation.quick) {
            viewModel.placeTile(tile)
        }
    }

    private func onTilePlacedTap(_ tile: WordOrderViewModel.Tile) {
        playIfAmharic(tile)
        withAnimation(reduceMotion ? nil : AppTheme.Animation.quick) {
            viewModel.removeTile(tile)
        }
    }

    private func playIfAmharic(_ tile: WordOrderViewModel.Tile) {
        guard let audioText = tile.audioText else { return }
        audio.play(audioText)
    }

    private func check() {
        viewModel.check()
        let generator = UIImpactFeedbackGenerator(style: viewModel.lastWasCorrect ? .medium : .heavy)
        generator.impactOccurred()
    }

    private func advance() {
        withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
            viewModel.advance()
        }
    }
}

// MARK: - Word Tile

struct WordTileButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    var transliteration: String?
    let isAmharic: Bool
    var isPlaced: Bool = false
    var isSpeaking: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(text)
                    .font(isAmharic ? AppTheme.Typography.amharic(size: 22) : AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                if let transliteration {
                    Text(transliteration)
                        .font(AppTheme.Typography.transliteration(size: 11))
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isPlaced ? AppTheme.primaryColor.opacity(0.12) : AppTheme.cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: isSpeaking ? 2 : 1)
                    )
            )
            .scaleEffect(isSpeaking ? 1.06 : 1.0)
            .animation(reduceMotion ? nil : AppTheme.Animation.quick, value: isSpeaking)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint(isAmharic ? "Plays pronunciation and places the word" : "Places the word")
    }

    private var borderColor: Color {
        if isSpeaking { return AppTheme.secondaryColor }
        return isPlaced ? AppTheme.primaryColor.opacity(0.5) : AppTheme.hairlineColor
    }
}

#Preview {
    NavigationStack {
        WordOrderView()
    }
    .modelContainer(for: [UserProgress.self, FlashcardProgress.self], inMemory: true)
}
