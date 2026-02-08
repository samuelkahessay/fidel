import SwiftUI
import SwiftData

struct SpeedDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var timeRemaining = 60
    @State private var isActive = true
    @State private var showResult = false
    @State private var userInput = ""
    @State private var showAnswer = false
    @State private var phrases: [Phrase] = []

    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var currentPhrase: Phrase? {
        currentIndex < phrases.count ? phrases[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Score: \(score)")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.primary)
                    Text("\(currentIndex)/\(phrases.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                CountdownTimer(seconds: timeRemaining)
            }
            .padding(AppTheme.Spacing.md)

            if let phrase = currentPhrase, !showResult {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Text("Translate to Amharic:")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.secondary)

                    Text(phrase.english)
                        .font(AppTheme.Typography.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    if showAnswer {
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Text(phrase.amharic)
                                .font(AppTheme.Typography.amharic(size: 40))
                                .foregroundColor(AppTheme.primaryColor)
                            Text(phrase.transliteration)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    HStack(spacing: AppTheme.Spacing.md) {
                        Button(action: {
                            withAnimation(AppTheme.Animation.standard) {
                                showAnswer = true
                            }
                        }) {
                            Label("Show", systemImage: "eye")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(showAnswer)

                        Button(action: { markCorrect() }) {
                            Label("Correct", systemImage: "checkmark")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(action: { nextQuestion() }) {
                            Label("Skip", systemImage: "forward")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(AppTheme.Spacing.md)
            } else if showResult {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Time's Up!")
                        .font(AppTheme.Typography.title)
                        .foregroundColor(.primary)

                    Text("Final Score: \(score)/\(phrases.count)")
                        .font(AppTheme.Typography.title2)
                        .foregroundColor(.secondary)

                    XPBadge(xp: score * 5)

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Speed Drill")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard isActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isActive = false
                showResult = true
            }
        }
        .onAppear {
            phrases = Array(lessonRepository.getPhrases().shuffled().prefix(20))
        }
    }

    private func markCorrect() {
        score += 1
        nextQuestion()
    }

    private func nextQuestion() {
        showAnswer = false
        if currentIndex < phrases.count - 1 {
            currentIndex += 1
        } else {
            showResult = true
            isActive = false
        }
    }
}
