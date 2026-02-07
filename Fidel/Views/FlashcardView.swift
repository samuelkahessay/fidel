import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = FlashcardViewModel()
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            progressHeader
            
            if let word = viewModel.currentWord, !viewModel.showCompletion {
                flashcardStack(word: word)
                swipeHints
            } else if viewModel.showCompletion {
                completionView
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let progressRepo = ProgressRepository(modelContext: modelContext)
            viewModel.configure(progressRepository: progressRepo)
            viewModel.startSession(cardCount: 20)
        }
    }
    
    private var progressHeader: some View {
        HStack {
            HStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(viewModel.correctCount)")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Text(viewModel.progress)
                .font(AppTheme.Typography.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: AppTheme.Spacing.xxs) {
                Text("\(viewModel.incorrectCount)")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.accentRed)
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppTheme.accentRed)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
    
    private func flashcardStack(word: VocabularyWord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.05),
                            lineWidth: 0.5
                        )
                )
            
            VStack(spacing: AppTheme.Spacing.lg) {
                if !viewModel.isFlipped {
                    frontContent(word: word)
                } else {
                    backContent(word: word)
                }
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .frame(height: 380)
        .rotation3DEffect(.degrees(viewModel.isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 25)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    handleSwipe(gesture: gesture)
                }
        )
        .onTapGesture {
            withAnimation(AppTheme.Animation.standard) {
                viewModel.flip()
            }
        }
        .overlay(swipeOverlay)
    }
    
    private func frontContent(word: VocabularyWord) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            
            Text(word.amharic)
                .font(.system(size: 64, weight: .medium))
                .foregroundColor(AppTheme.primaryColor)
            
            Text(word.transliteration)
                .font(AppTheme.Typography.title3)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: "hand.tap")
                    .font(.caption)
                Text("Tap to flip")
                    .font(AppTheme.Typography.caption)
            }
            .foregroundStyle(.tertiary)
        }
    }
    
    private func backContent(word: VocabularyWord) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            
            Text(word.english)
                .font(AppTheme.Typography.title)
                .foregroundColor(.primary)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            
            Text(word.category)
                .font(AppTheme.Typography.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xxs)
                .background(
                    Capsule()
                        .fill(AppTheme.primaryColor.opacity(0.12))
                )
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            
            Spacer()
            
            HStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                Text("Swipe right if correct, left if not")
                    .font(AppTheme.Typography.caption)
            }
            .foregroundStyle(.tertiary)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }
    
    private var swipeOverlay: some View {
        ZStack {
            if offset.width > 50 {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                    .stroke(Color.green, lineWidth: 3)
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                    )
            } else if offset.width < -50 {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                    .stroke(AppTheme.accentRed, lineWidth: 3)
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.accentRed)
                    )
            }
        }
    }
    
    private var swipeHints: some View {
        HStack(spacing: AppTheme.Spacing.xxl) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(AppTheme.accentRed.opacity(0.5))
                Text("Still learning")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green.opacity(0.5))
                Text("Got it!")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, AppTheme.Spacing.lg)
    }
    
    private var completionView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            AnimatedCheckmark()
            
            Text("Session Complete!")
                .font(AppTheme.Typography.title)
                .foregroundColor(.primary)
            
            HStack(spacing: AppTheme.Spacing.xxl) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.correctCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.green)
                    Text("Correct")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.incorrectCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(AppTheme.accentRed)
                    Text("To Review")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: AppTheme.Spacing.xs) {
                ProgressRing(progress: Double(viewModel.correctCount) / Double(max(viewModel.vocabulary.count, 1)), lineWidth: 6, size: 44)
                Text("\(viewModel.accuracyPercentage)% Accuracy")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.primaryColor)
            }
            
            XPBadge(xp: viewModel.earnedXP())
        }
        .glassCard()
    }
    
    private func handleSwipe(gesture: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        withAnimation(AppTheme.Animation.standard) {
            if gesture.translation.width > threshold {
                offset = CGSize(width: 500, height: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.handleSwipe(correct: true)
                    offset = .zero
                }
            } else if gesture.translation.width < -threshold {
                offset = CGSize(width: -500, height: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.handleSwipe(correct: false)
                    offset = .zero
                }
            } else {
                offset = .zero
            }
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardView()
    }
    .modelContainer(for: [FlashcardProgress.self], inMemory: true)
}
