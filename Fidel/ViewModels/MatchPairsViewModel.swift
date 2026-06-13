import Foundation

/// Drives the Match Pairs exercise (Duolingo's "tap the pairs"): two columns of
/// five tiles each (Amharic and English); tap one then its translation to clear
/// the pair. Runs several rounds of fresh vocabulary, then a summary.
@MainActor
@Observable
final class MatchPairsViewModel {

    struct Tile: Identifiable, Hashable {
        let id = UUID()
        let wordId: String
        let text: String
        let transliteration: String
        let isAmharic: Bool
        var isMatched = false
    }

    let pairsPerRound = 5
    private(set) var roundsTotal = 3

    var amharicTiles: [Tile] = []
    var englishTiles: [Tile] = []
    var selectedTileId: UUID?
    var wrongTileIds: Set<UUID> = []
    var currentRound = 0
    var showResult = false

    private(set) var totalMatched = 0
    private(set) var mistakes = 0
    private var matchedThisRound = 0
    private var sessionWords: [VocabularyWord] = []
    private var didAwardXP = false
    private var clearWrongTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    private let lessonRepository: LessonRepositoryProtocol
    private var progressRepository: ProgressRepositoryProtocol?

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    func configure(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    var pairsRequired: Int { roundsTotal * pairsPerRound }

    /// Each matched pair awards 5 XP (via masterVocabulary) plus a small bonus.
    var earnedXP: Int { totalMatched * 5 + (totalMatched == pairsRequired ? 10 : 0) }

    // MARK: - Session lifecycle

    func startSession() {
        let pool = dedupedVocabulary().shuffled()
        roundsTotal = max(1, min(3, pool.count / pairsPerRound))
        sessionWords = Array(pool.prefix(roundsTotal * pairsPerRound))
        currentRound = 0
        totalMatched = 0
        mistakes = 0
        didAwardXP = false
        showResult = false
        loadRound()
    }

    func restart() {
        startSession()
    }

    private func loadRound() {
        clearWrongTask?.cancel()
        advanceTask?.cancel()
        selectedTileId = nil
        wrongTileIds = []
        matchedThisRound = 0

        let start = currentRound * pairsPerRound
        let words = Array(sessionWords[start ..< min(start + pairsPerRound, sessionWords.count)])
        amharicTiles = words.map {
            Tile(wordId: $0.id, text: $0.amharic, transliteration: $0.transliteration, isAmharic: true)
        }.shuffled()
        englishTiles = words.map {
            Tile(wordId: $0.id, text: $0.english, transliteration: $0.transliteration, isAmharic: false)
        }.shuffled()
    }

    // MARK: - Interaction

    /// Returns the Amharic text to pronounce when an Amharic tile is tapped, else nil.
    @discardableResult
    func select(_ tile: Tile) -> String? {
        guard !tile.isMatched, !showResult else { return nil }
        let audioText = tile.isAmharic ? tile.text : nil

        guard let selectedId = selectedTileId, let selected = findTile(id: selectedId) else {
            selectedTileId = tile.id
            return audioText
        }

        // Tapping the same tile, or another tile in the same column, just moves selection.
        if selected.id == tile.id || selected.isAmharic == tile.isAmharic {
            selectedTileId = tile.id
            return audioText
        }

        // Opposite columns → evaluate the pair.
        if selected.wordId == tile.wordId {
            markMatched(selected.id, tile.id, wordId: tile.wordId)
        } else {
            registerMismatch(selected.id, tile.id)
        }
        selectedTileId = nil
        return audioText
    }

    private func markMatched(_ idA: UUID, _ idB: UUID, wordId: String) {
        setMatched(idA, true)
        setMatched(idB, true)
        matchedThisRound += 1
        totalMatched += 1
        progressRepository?.masterVocabulary(wordId)

        if matchedThisRound == pairsPerRound {
            advanceTask?.cancel()
            advanceTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                self?.advanceRound()
            }
        }
    }

    private func registerMismatch(_ idA: UUID, _ idB: UUID) {
        mistakes += 1
        wrongTileIds = [idA, idB]
        clearWrongTask?.cancel()
        clearWrongTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.wrongTileIds = []
        }
    }

    private func advanceRound() {
        if currentRound >= roundsTotal - 1 {
            showResult = true
            awardXPIfNeeded()
        } else {
            currentRound += 1
            loadRound()
        }
    }

    private func awardXPIfNeeded() {
        guard !didAwardXP else { return }
        didAwardXP = true
        if totalMatched == pairsRequired {
            progressRepository?.addXP(10) // completion bonus; per-pair XP already awarded via masterVocabulary
        }
    }

    // MARK: - Helpers

    func isSelected(_ tile: Tile) -> Bool { selectedTileId == tile.id }
    func isWrong(_ tile: Tile) -> Bool { wrongTileIds.contains(tile.id) }

    private func findTile(id: UUID) -> Tile? {
        amharicTiles.first { $0.id == id } ?? englishTiles.first { $0.id == id }
    }

    private func setMatched(_ id: UUID, _ value: Bool) {
        if let i = amharicTiles.firstIndex(where: { $0.id == id }) { amharicTiles[i].isMatched = value }
        if let i = englishTiles.firstIndex(where: { $0.id == id }) { englishTiles[i].isMatched = value }
    }

    /// De-duplicates by English meaning and Amharic spelling so a round never
    /// contains two tiles that could both be a valid match.
    private func dedupedVocabulary() -> [VocabularyWord] {
        var seenEnglish = Set<String>()
        var seenAmharic = Set<String>()
        var result: [VocabularyWord] = []
        for word in lessonRepository.getVocabulary() {
            let english = word.english.lowercased()
            if seenEnglish.contains(english) || seenAmharic.contains(word.amharic) { continue }
            seenEnglish.insert(english)
            seenAmharic.insert(word.amharic)
            result.append(word)
        }
        return result
    }
}
