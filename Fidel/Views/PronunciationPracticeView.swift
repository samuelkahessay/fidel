import SwiftUI

private struct PronunciationPracticeItem: Identifiable {
    let phrase: Phrase
    let asset: AudioAsset
    let url: URL

    var id: String { asset.id }
}

struct PronunciationPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var audioService = BundledAudioService()
    @State private var currentIndex = 0

    private let lessonRepository: LessonRepositoryProtocol
    private let audioRepository: AudioAssetRepository

    init(
        lessonRepository: LessonRepositoryProtocol = LessonRepository.shared,
        audioRepository: AudioAssetRepository = .shared
    ) {
        self.lessonRepository = lessonRepository
        self.audioRepository = audioRepository
    }

    private var practiceItems: [PronunciationPracticeItem] {
        lessonRepository.getPhrases().compactMap { phrase in
            guard let asset = audioRepository.asset(for: phrase),
                  let url = audioRepository.audioURL(for: asset) else {
                return nil
            }
            return PronunciationPracticeItem(phrase: phrase, asset: asset, url: url)
        }
    }

    private var currentItem: PronunciationPracticeItem? {
        guard currentIndex < practiceItems.count else { return nil }
        return practiceItems[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if practiceItems.isEmpty {
                    unavailableView
                } else if let item = currentItem {
                    ScrollView {
                        VStack(spacing: 24) {
                            progressIndicator
                            mainCard(item: item)
                            listenSection(item: item)
                            practiceControls(item: item)
                        }
                        .padding()
                    }
                } else {
                    completionView
                }
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle("Pronunciation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .fidelTabBarHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", systemImage: "forward.fill", action: moveToNext)
                        .labelStyle(.iconOnly)
                        .disabled(practiceItems.isEmpty || currentItem == nil)
                }
            }
        }
    }

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) of \(practiceItems.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(Double(currentIndex) / Double(practiceItems.count) * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.primaryColor)
            }

            ProgressView(value: Double(currentIndex), total: Double(practiceItems.count))
                .tint(AppTheme.primaryColor)
        }
    }

    private func mainCard(item: PronunciationPracticeItem) -> some View {
        VStack(spacing: 16) {
            Text(item.phrase.amharic)
                .font(AppTheme.Typography.amharic(size: 36))
                .foregroundStyle(AppTheme.primaryColor)
                .multilineTextAlignment(.center)

            Text(item.phrase.transliteration)
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            Text(item.phrase.english)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Shadow.elevated, radius: 10, y: 5)
        )
    }

    private func listenSection(item: PronunciationPracticeItem) -> some View {
        VStack(spacing: 12) {
            Text("Generated pronunciation")
                .font(.headline)

            Button {
                audioService.play(asset: item.asset, url: item.url)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: audioService.playingAssetId == item.asset.id ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                    Text(audioService.playingAssetId == item.asset.id ? "Playing" : "Play")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .frame(width: 88, height: 88)
                .background(Circle().fill(AppTheme.primaryColor))
            }
            .accessibilityLabel("Play generated pronunciation")
            .accessibilityHint("Plays generated pronunciation for \(item.phrase.amharic)")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Shadow.card, radius: 8, y: 4)
        )
    }

    private func practiceControls(item: PronunciationPracticeItem) -> some View {
        HStack(spacing: 16) {
            Button {
                audioService.play(asset: item.asset, url: item.url)
            } label: {
                Label("Again", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(action: moveToNext) {
                Label(isLastItem ? "Finish" : "Next", systemImage: isLastItem ? "checkmark" : "arrow.right")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var unavailableView: some View {
        EmptyStateView(
            icon: "speaker.slash",
            title: "No Clips",
            message: "Generated pronunciation clips are not available yet."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.primaryColor)

            Text("Practice Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("You practiced \(practiceItems.count) generated clips")
                .foregroundStyle(.secondary)

            Button("Practice Again") {
                currentIndex = 0
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isLastItem: Bool {
        currentIndex >= practiceItems.count - 1
    }

    private func moveToNext() {
        guard currentIndex < practiceItems.count else { return }
        currentIndex += 1
        audioService.stop()
    }
}

#Preview {
    PronunciationPracticeView()
}
