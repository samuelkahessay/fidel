import Foundation

@MainActor
@Observable
final class ReferenceViewModel {
    var searchText = ""
    var selectedCategory: String?

    private let lessonRepository: LessonRepositoryProtocol

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    var phrases: [Phrase] {
        let allPhrases = lessonRepository.getPhrases()
        if searchText.isEmpty {
            return allPhrases
        }
        return allPhrases.filter {
            $0.amharic.contains(searchText) ||
            $0.english.lowercased().contains(searchText.lowercased()) ||
            $0.transliteration.lowercased().contains(searchText.lowercased())
        }
    }

    var vocabulary: [VocabularyWord] {
        if let category = selectedCategory {
            return lessonRepository.getVocabulary(for: category)
        }
        let allVocab = lessonRepository.getVocabulary()
        if searchText.isEmpty {
            return allVocab
        }
        return allVocab.filter {
            $0.amharic.contains(searchText) ||
            $0.english.lowercased().contains(searchText.lowercased()) ||
            $0.transliteration.lowercased().contains(searchText.lowercased())
        }
    }

    var vocabularyCategories: [String] {
        lessonRepository.getVocabularyCategories()
    }

    var numbers: [AmharicNumber] {
        lessonRepository.getNumbers()
    }

    func selectCategory(_ category: String?) {
        selectedCategory = category
    }

    func clearSearch() {
        searchText = ""
    }
}
