import Foundation
import SwiftData

// MARK: - Rating

enum ReviewRating: Int {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

// MARK: - FSRS Algorithm

struct FSRSAlgorithm {
    
    private static let DECAY: Double = -0.5
    private static let FACTOR: Double = 19.0 / 81.0
    
    private static let weights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949,
        0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698,
        0.2315, 2.9898, 0.51655, 0.6621
    ]
    
    static let requestRetention: Double = 0.9
    static let maximumInterval: Double = 36500
    
    static func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + (FACTOR * elapsedDays) / stability, DECAY)
    }
    
    static func initStability(rating: ReviewRating) -> Double {
        max(weights[rating.rawValue - 1], 0.1)
    }
    
    static func initDifficulty(rating: ReviewRating) -> Double {
        let d = weights[4] - exp((Double(rating.rawValue) - 1) * weights[5]) + 1
        return min(max(d, 1.0), 10.0)
    }
    
    static func nextRecallStability(d: Double, s: Double, r: Double, g: ReviewRating) -> Double {
        let hardPenalty = g == .hard ? weights[15] : 1.0
        let easyBonus = g == .easy ? weights[16] : 1.0
        
        let newS = s * (
            1 + exp(weights[8]) * (11 - d) * pow(s, -weights[9]) *
            (exp((1 - r) * weights[10]) - 1) * hardPenalty * easyBonus
        )
        
        return min(max(newS, 0.01), maximumInterval)
    }
    
    static func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        let newS = weights[11] * pow(d, -weights[12]) * (pow(s + 1, weights[13]) - 1) * exp((1 - r) * weights[14])
        return min(max(newS, 0.01), maximumInterval)
    }
    
    static func nextDifficulty(d: Double, g: ReviewRating) -> Double {
        let deltaD = -weights[6] * Double(g.rawValue - 3)
        let dampedDelta = deltaD * (10 - d) / 9
        let nextD = d + dampedDelta
        let meanReverted = weights[7] * initDifficulty(rating: .easy) + (1 - weights[7]) * nextD
        return min(max(meanReverted, 1.0), 10.0)
    }
    
    static func nextInterval(stability: Double) -> Int {
        let modifier = (pow(requestRetention, 1 / DECAY) - 1) / FACTOR
        let interval = stability * modifier
        return Int(min(max(1, round(interval)), maximumInterval))
    }
    
    static func calculateNextReview(
        rating: ReviewRating,
        currentStability: Double,
        currentDifficulty: Double,
        elapsedDays: Double
    ) -> (newInterval: Int, newStability: Double, newDifficulty: Double) {
        
        var stability = currentStability
        var difficulty = currentDifficulty
        
        if stability == 0 && difficulty == 0 {
            stability = initStability(rating: rating)
            difficulty = initDifficulty(rating: rating)
        } else {
            let retrievability = forgettingCurve(elapsedDays: elapsedDays, stability: stability)
            
            if rating == .again {
                stability = nextForgetStability(d: difficulty, s: stability, r: retrievability)
            } else {
                stability = nextRecallStability(d: difficulty, s: stability, r: retrievability, g: rating)
            }
            difficulty = nextDifficulty(d: difficulty, g: rating)
        }
        
        let interval = nextInterval(stability: stability)
        return (interval, stability, difficulty)
    }
    
    static func updateFlashcardProgress(
        progress: FlashcardProgress,
        rating: ReviewRating
    ) {
        let elapsedDays = progress.lastReviewDate.map {
            Calendar.current.dateComponents([.day], from: $0, to: Date.now).day ?? 0
        } ?? 0
        
        let result = calculateNextReview(
            rating: rating,
            currentStability: progress.stability,
            currentDifficulty: progress.difficulty,
            elapsedDays: Double(elapsedDays)
        )
        
        progress.interval = result.newInterval
        progress.stability = result.newStability
        progress.difficulty = result.newDifficulty
        progress.lastReviewDate = Date.now
        progress.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: result.newInterval,
            to: Date.now
        ) ?? Date.now
        progress.repetitions += 1
        progress.updatedAt = Date.now
        
        if rating == .again {
            progress.lapses += 1
        }
    }
    
    static func getDueCards(from cards: [FlashcardProgress]) -> [FlashcardProgress] {
        let now = Date.now
        return cards.filter { $0.nextReviewDate <= now }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }
    
    static func getUpcomingCards(from cards: [FlashcardProgress], days: Int = 7) -> [FlashcardProgress] {
        let now = Date.now
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        
        return cards.filter { $0.nextReviewDate > now && $0.nextReviewDate <= futureDate }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }
    
    static func getRetrievability(for progress: FlashcardProgress) -> Double {
        guard progress.stability > 0 else { return 1.0 }
        
        let elapsedDays = progress.lastReviewDate.map {
            Double(Calendar.current.dateComponents([.day], from: $0, to: Date.now).day ?? 0)
        } ?? 0
        
        return forgettingCurve(elapsedDays: elapsedDays, stability: progress.stability)
    }
}

// MARK: - Legacy SM-2 Compatibility

enum ReviewQuality: Int {
    case again = 0
    case hard = 1
    case good = 2
    case easy = 3
    
    var toFSRSRating: ReviewRating {
        switch self {
        case .again: return .again
        case .hard: return .hard
        case .good: return .good
        case .easy: return .easy
        }
    }
}

struct SpacedRepetitionAlgorithm {
    
    static func calculateNextReview(
        quality: ReviewQuality,
        currentEaseFactor: Double,
        currentInterval: Int,
        currentRepetitions: Int
    ) -> (newInterval: Int, newEaseFactor: Double, newRepetitions: Int) {
        
        let stability = currentEaseFactor > 0 ? Double(currentInterval) / currentEaseFactor : 0
        let difficulty = 11.0 - currentEaseFactor
        
        let result = FSRSAlgorithm.calculateNextReview(
            rating: quality.toFSRSRating,
            currentStability: stability,
            currentDifficulty: max(1, min(10, difficulty)),
            elapsedDays: Double(currentInterval)
        )
        
        let newEaseFactor = 11.0 - result.newDifficulty
        let newRepetitions = quality == .again ? 0 : currentRepetitions + 1
        
        return (result.newInterval, newEaseFactor, newRepetitions)
    }
    
    static func updateFlashcardProgress(
        progress: FlashcardProgress,
        quality: ReviewQuality
    ) {
        FSRSAlgorithm.updateFlashcardProgress(progress: progress, rating: quality.toFSRSRating)
    }
    
    static func getDueCards(from cards: [FlashcardProgress]) -> [FlashcardProgress] {
        FSRSAlgorithm.getDueCards(from: cards)
    }
    
    static func getUpcomingCards(from cards: [FlashcardProgress], days: Int = 7) -> [FlashcardProgress] {
        FSRSAlgorithm.getUpcomingCards(from: cards, days: days)
    }
}

// MARK: - FlashcardManager

@MainActor
class FlashcardManager {
    private let modelContext: ModelContext
    private let explicitUserId: String?
    private var activeUserId: String {
        explicitUserId ?? AuthManager.shared.currentUserId ?? AuthManager.previewUserId
    }
    
    init(modelContext: ModelContext, userId: String? = nil) {
        self.modelContext = modelContext
        self.explicitUserId = userId
    }
    
    func getOrCreateProgress(for itemId: String, type: String) -> FlashcardProgress {
        let ownerId = activeUserId
        let descriptor = FetchDescriptor<FlashcardProgress>(
            predicate: #Predicate<FlashcardProgress> {
                $0.ownerUserId == ownerId && $0.itemId == itemId && $0.itemType == type
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        let newProgress = FlashcardProgress(itemId: itemId, itemType: type, ownerUserId: ownerId)
        modelContext.insert(newProgress)
        return newProgress
    }
    
    func recordReview(for itemId: String, type: String, rating: ReviewRating) {
        let progress = getOrCreateProgress(for: itemId, type: type)
        FSRSAlgorithm.updateFlashcardProgress(progress: progress, rating: rating)
    }
    
    func recordReview(for itemId: String, type: String, quality: ReviewQuality) {
        recordReview(for: itemId, type: type, rating: quality.toFSRSRating)
    }
    
    func getDueItems(type: String? = nil) -> [FlashcardProgress] {
        let ownerId = activeUserId
        let descriptor: FetchDescriptor<FlashcardProgress>
        
        if let type = type {
            descriptor = FetchDescriptor<FlashcardProgress>(
                predicate: #Predicate<FlashcardProgress> {
                    $0.ownerUserId == ownerId && $0.itemType == type
                }
            )
        } else {
            descriptor = FetchDescriptor<FlashcardProgress>(
                predicate: #Predicate<FlashcardProgress> { $0.ownerUserId == ownerId }
            )
        }
        
        guard let allProgress = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return FSRSAlgorithm.getDueCards(from: allProgress)
    }
    
    func initializeVocabularyCards() {
        for word in AmharicData.vocabulary {
            _ = getOrCreateProgress(for: word.id, type: "vocabulary")
        }
        
        for phrase in AmharicData.phrases {
            _ = getOrCreateProgress(for: String(phrase.id), type: "phrase")
        }
    }
}
