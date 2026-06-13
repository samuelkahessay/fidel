import SwiftUI
import SwiftData

/// Duolingo-style "tap the pairs": match five Amharic words to their English
/// meanings. Tapping an Amharic tile plays its pronunciation. Correct pairs
/// clear; wrong pairs flash and reset. Several rounds, then a summary.
struct MatchPairsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = MatchPairsViewModel()
    @State private var audio = WordAudioPlayer()
    @State private var didSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                if viewModel.showResult {
                    resultsView
                } else {
                    roundContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Match Pairs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .onAppear(perform: setup)
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        viewModel.configure(progressRepository: ProgressRepository(modelContext: modelContext))
        viewModel.startSession()
    }

    // MARK: - Round

    private var roundContent: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            progressHeader

            Text("Tap an Amharic word, then its English match")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                column(tiles: viewModel.amharicTiles)
                column(tiles: viewModel.englishTiles)
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ProgressView(
                value: Double(viewModel.totalMatched),
                total: Double(max(viewModel.pairsRequired, 1))
            )
            .tint(AppTheme.primaryColor)
            .accessibilityLabel("Pairs matched")
            .accessibilityValue("\(viewModel.totalMatched) of \(viewModel.pairsRequired)")

            HStack {
                Text("Round \(viewModel.currentRound + 1) of \(viewModel.roundsTotal)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                Spacer()
                Text("Matched: \(viewModel.totalMatched)/\(viewModel.pairsRequired)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.primaryColor)
            }
        }
    }

    private func column(tiles: [MatchPairsViewModel.Tile]) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(tiles) { tile in
                MatchTileButton(
                    text: tile.text,
                    transliteration: tile.isAmharic ? tile.transliteration : nil,
                    isAmharic: tile.isAmharic,
                    isSelected: viewModel.isSelected(tile),
                    isMatched: tile.isMatched,
                    isWrong: viewModel.isWrong(tile),
                    reduceMotion: reduceMotion
                ) {
                    onTap(tile)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: viewModel.mistakes == 0 ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(viewModel.mistakes == 0 ? AppTheme.secondaryColor : AppTheme.successColor)

            Text("Pairs Complete!")
                .font(AppTheme.Typography.title)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(viewModel.totalMatched) pairs")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.primaryColor)
                Text(viewModel.mistakes == 0 ? "Flawless — no mistakes!" : "\(viewModel.mistakes) mistake\(viewModel.mistakes == 1 ? "" : "s")")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            XPBadge(xp: viewModel.earnedXP)

            VStack(spacing: AppTheme.Spacing.sm) {
                Button(action: { viewModel.restart() }) {
                    Label("Play Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))

                Button(action: { dismiss() }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(isFullWidth: true))
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Actions

    private func onTap(_ tile: MatchPairsViewModel.Tile) {
        withAnimation(reduceMotion ? nil : AppTheme.Animation.quick) {
            let audioText = viewModel.select(tile)
            if let audioText { audio.play(audioText) }
        }
        if viewModel.isWrong(tile) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
}

// MARK: - Match Tile

struct MatchTileButton: View {
    let text: String
    var transliteration: String?
    let isAmharic: Bool
    let isSelected: Bool
    let isMatched: Bool
    let isWrong: Bool
    var reduceMotion: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(text)
                    .font(isAmharic ? AppTheme.Typography.amharic(size: 22) : AppTheme.Typography.headline)
                    .foregroundStyle(isMatched ? AppTheme.successColor : AppTheme.inkColor)
                    .multilineTextAlignment(.center)
                if let transliteration {
                    Text(transliteration)
                        .font(AppTheme.Typography.transliteration(size: 11))
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                            .stroke(borderColor, lineWidth: isSelected || isWrong ? 2 : 1)
                    )
            )
            .opacity(isMatched ? 0.45 : 1)
            .modifier(ShakeEffect(animatableData: (isWrong && !reduceMotion) ? 1 : 0))
            .animation(reduceMotion ? nil : AppTheme.Animation.quick, value: isWrong)
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
        .accessibilityLabel(text)
        .accessibilityValue(isMatched ? "Matched" : (isSelected ? "Selected" : ""))
        .accessibilityHint(isAmharic ? "Plays pronunciation and selects the word" : "Selects the word")
    }

    private var fillColor: Color {
        if isMatched { return AppTheme.successColor.opacity(0.15) }
        if isWrong { return AppTheme.accentRed.opacity(0.15) }
        if isSelected { return AppTheme.primaryColor.opacity(0.15) }
        return AppTheme.cardColor
    }

    private var borderColor: Color {
        if isMatched { return AppTheme.successColor }
        if isWrong { return AppTheme.accentRed }
        if isSelected { return AppTheme.primaryColor }
        return AppTheme.hairlineColor
    }
}

/// A brief horizontal shake used to reject a wrong pair.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 6
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: travel * sin(animatableData * .pi * CGFloat(shakesPerUnit)), y: 0)
        )
    }
}

#Preview {
    NavigationStack {
        MatchPairsView()
    }
    .modelContainer(for: [UserProgress.self, FlashcardProgress.self], inMemory: true)
}
