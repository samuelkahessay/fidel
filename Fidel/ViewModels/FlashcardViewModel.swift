import Foundation
import SwiftUI

@Observable
final class FlashcardViewModel {
    var currentIndex = 0
    var isFlipped = false
    var offset: CGSize = .zero
    var showCompletion = false
    var correctCount = 0
    var incorrectCount = 0

    private(set) var vocabulary: [VocabularyWord] = []

    private let lessonRepository: LessonRepositoryProtocol
    private var progressRepository: ProgressRepositoryProtocol?

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    func startSession(cardCount: Int = 20, vocabulary filteredVocabulary: [VocabularyWord]? = nil) {
        if let filtered = filteredVocabulary, !filtered.isEmpty {
            vocabulary = Array(filtered.shuffled().prefix(cardCount))
        } else {
            vocabulary = lessonRepository.getShuffledVocabulary(count: cardCount)
        }
        currentIndex = 0
        isFlipped = false
        offset = .zero
        showCompletion = false
        correctCount = 0
        incorrectCount = 0
    }

    var currentWord: VocabularyWord? {
        currentIndex < vocabulary.count ? vocabulary[currentIndex] : nil
    }

    var progress: String {
        "\(currentIndex + 1)/\(vocabulary.count)"
    }

    var accuracyPercentage: Int {
        vocabulary.count > 0 ? Int((Double(correctCount) / Double(vocabulary.count)) * 100) : 0
    }

    func flip() {
        isFlipped.toggle()
    }

    func handleSwipe(correct: Bool) {
        if correct {
            correctCount += 1
            recordReview(rating: .good)
        } else {
            incorrectCount += 1
            recordReview(rating: .again)
        }
        nextCard()
    }

    private func recordReview(rating: ReviewRating) {
        guard let word = currentWord else { return }
        progressRepository?.recordFlashcardReview(for: word.id, type: "vocabulary", rating: rating)
    }

    private func nextCard() {
        if currentIndex < vocabulary.count - 1 {
            currentIndex += 1
            isFlipped = false
        } else {
            showCompletion = true
        }
    }

    func earnedXP() -> Int {
        correctCount * 5
    }
}
