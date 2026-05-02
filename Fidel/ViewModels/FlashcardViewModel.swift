import Foundation
import SwiftUI

@MainActor
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
        let sourceVocabulary: [VocabularyWord]
        if let filtered = filteredVocabulary, !filtered.isEmpty {
            sourceVocabulary = filtered
        } else {
            sourceVocabulary = lessonRepository.getVocabulary()
        }

        progressRepository?.initializeFlashcards(
            vocabulary: sourceVocabulary,
            phrases: filteredVocabulary == nil ? lessonRepository.getPhrases() : []
        )

        let vocabularyById = Dictionary(uniqueKeysWithValues: sourceVocabulary.map { ($0.id, $0) })
        let dueWords = progressRepository?
            .getDueFlashcards(type: "vocabulary")
            .compactMap { vocabularyById[$0.itemId] } ?? []
        let dueIds = Set(dueWords.map(\.id))
        let fillWords = sourceVocabulary
            .filter { !dueIds.contains($0.id) }
            .shuffled()

        vocabulary = Array((dueWords + fillWords).prefix(cardCount))
        if vocabulary.isEmpty {
            vocabulary = Array(sourceVocabulary.shuffled().prefix(cardCount))
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
