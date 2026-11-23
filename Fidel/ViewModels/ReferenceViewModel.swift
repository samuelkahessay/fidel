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
            $0.amharic.contains(searchText) || $0.english.lowercased().contains(searchText.lowercased())
                || $0.transliteration.lowercased().contains(searchText.lowercased())
        }
    }

    var phraseSections: [PhraseSection] {
        let categoryByPhraseId = lessonPhraseCategoryById()
        let grouped = Dictionary(grouping: phrases) { phrase in
            categoryByPhraseId[phrase.id] ?? "Everyday Reference"
        }

        return
            grouped
            .map { PhraseSection(title: $0.key, phrases: $0.value.sorted { $0.id < $1.id }) }
            .sorted { lhs, rhs in
                sectionSortKey(lhs.title) < sectionSortKey(rhs.title)
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
            $0.amharic.contains(searchText) || $0.english.lowercased().contains(searchText.lowercased())
                || $0.transliteration.lowercased().contains(searchText.lowercased())
        }
    }

    var vocabularyCategories: [String] {
        lessonRepository.getVocabularyCategories()
    }

    var numbers: [AmharicNumber] {
        lessonRepository.getNumbers()
    }

    var ethiopianMonths: [EthiopianMonth] {
        lessonRepository.getEthiopianMonths()
    }

    var ordinalNumbers: [OrdinalNumber] {
        lessonRepository.getOrdinalNumbers()
    }

    var fractions: [AmharicFraction] {
        lessonRepository.getFractions()
    }

    var culturalNotes: [CulturalNote] {
        let notes = lessonRepository.getCulturalNotes()
        if searchText.isEmpty {
            return notes
        }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.amharicTitle.contains(searchText)
                || $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    func selectCategory(_ category: String?) {
        selectedCategory = category
    }

    func clearSearch() {
        searchText = ""
    }

    private func lessonPhraseCategoryById() -> [Int: String] {
        var result: [Int: String] = [:]
        for lesson in lessonRepository.getLessons() {
            let title = "Lesson \(lesson.id): \(lesson.title)"
            for phrase in lesson.phrases {
                result[phrase.id] = title
            }
        }
        return result
    }

    private func sectionSortKey(_ title: String) -> String {
        if title == "Everyday Reference" {
            return "999-\(title)"
        }
        return title
    }
}

struct PhraseSection: Identifiable {
    var id: String { title }
    let title: String
    let phrases: [Phrase]
}
