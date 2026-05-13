import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = FlashcardViewModel()
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            progressHeader
            
            if let word = viewModel.currentWord, !viewModel.showCompletion {
                flashcardStack(word: word)
                reviewControls
                swipeHints
            } else if viewModel.showCompletion {
                completionView
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.groupedBackground)
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
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
                    .foregroundStyle(AppTheme.successColor)
                Text("\(viewModel.correctCount)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.successColor)
            }
            
            Spacer()
            
            Text(viewModel.progress)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: AppTheme.Spacing.xxs) {
                Text("\(viewModel.incorrectCount)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.accentRed)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppTheme.accentRed)
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
        .rotation3DEffect(.degrees(reduceMotion ? 0 : (viewModel.isFlipped ? 180 : 0)), axis: (x: 0, y: 1, z: 0))
        .offset(offset)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 25)))
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
            withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
                viewModel.flip()
            }
        }
        .overlay(swipeOverlay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isFlipped ? "\(word.english), \(word.category)" : "\(word.amharic), \(word.transliteration)")
        .accessibilityHint(viewModel.isFlipped ? "Use the review buttons below" : "Double tap to show the answer")
        .accessibilityAction(named: "Flip card") {
            viewModel.flip()
        }
    }
    
    private func frontContent(word: VocabularyWord) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            
            Text(word.amharic)
                .font(AppTheme.Typography.amharic(size: 64))
                .foregroundStyle(AppTheme.primaryColor)
            
            Text(word.transliteration)
                .font(AppTheme.Typography.title3)
                .foregroundStyle(.secondary)
            
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
                .foregroundStyle(.primary)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            
            Text(word.category)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xxs)
                .background(
                    Capsule()
                        .fill(AppTheme.primaryColor.opacity(0.12))
                )
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            
            Spacer()
            
            HStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                Text("Swipe right if correct, left if not")
                    .font(AppTheme.Typography.caption)
            }
            .foregroundStyle(.tertiary)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private var reviewControls: some View {
        Group {
            if viewModel.isFlipped {
                HStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        answerCard(correct: false)
                    } label: {
                        Label("Still Learning", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("Marks this card for more review")

                    Button {
                        answerCard(correct: true)
                    } label: {
                        Label("Got It", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Marks this card correct")
                }
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
                        viewModel.flip()
                    }
                } label: {
                    Label("Show Answer", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            }
        }
    }
    
    private var swipeOverlay: some View {
        ZStack {
            if offset.width > 50 {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                    .stroke(AppTheme.successColor, lineWidth: 3)
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.successColor)
                    )
            } else if offset.width < -50 {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                    .stroke(AppTheme.accentRed, lineWidth: 3)
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.accentRed)
                    )
            }
        }
    }
    
    private var swipeHints: some View {
        HStack(spacing: AppTheme.Spacing.xxl) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(AppTheme.accentRed.opacity(0.5))
                Text("Still learning")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(AppTheme.successColor.opacity(0.5))
                Text("Got it!")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, AppTheme.Spacing.lg)
    }
    
    private var completionView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            AnimatedCheckmark()
            
            Text("Session Complete!")
                .font(AppTheme.Typography.title)
                .foregroundStyle(.primary)
            
            HStack(spacing: AppTheme.Spacing.xxl) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.correctCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(AppTheme.successColor)
                    Text("Correct")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Text("\(viewModel.incorrectCount)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(AppTheme.accentRed)
                    Text("To Review")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: AppTheme.Spacing.xs) {
                AccessibleProgressRing(
                    progress: Double(viewModel.correctCount) / Double(max(viewModel.vocabulary.count, 1)),
                    lineWidth: 6,
                    size: 44,
                    label: "Flashcard accuracy",
                    valueText: "\(viewModel.accuracyPercentage) percent"
                )
                Text("\(viewModel.accuracyPercentage)% Accuracy")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.primaryColor)
            }
            
            XPBadge(xp: viewModel.earnedXP())
        }
        .glassCard()
    }
    
    private func handleSwipe(gesture: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
            if gesture.translation.width > threshold {
                offset = CGSize(width: 500, height: 0)
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    viewModel.handleSwipe(correct: true)
                    offset = .zero
                }
            } else if gesture.translation.width < -threshold {
                offset = CGSize(width: -500, height: 0)
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    viewModel.handleSwipe(correct: false)
                    offset = .zero
                }
            } else {
                offset = .zero
            }
        }
    }

    private func answerCard(correct: Bool) {
        withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
            offset = correct ? CGSize(width: 500, height: 0) : CGSize(width: -500, height: 0)
        }
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.2))
            viewModel.handleSwipe(correct: correct)
            offset = .zero
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardView()
    }
    .modelContainer(for: [FlashcardProgress.self], inMemory: true)
}
