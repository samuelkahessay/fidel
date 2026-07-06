import Foundation
import SwiftData

/// Per-character guided tracing progression.
///
/// Levels: 0 = never completed, 1 = traced with full guide, 2 = traced with
/// faint guide, 3 = written from memory (mastered). Dedicated model rather
/// than FlashcardProgress: FSRS scheduling fields are meaningless for tracing,
/// and tracing rows must not leak into flashcard review queues.
@Model
final class CharacterTraceMastery {
    var ownerUserId: String = ""
    /// FidelCharacter.id, e.g. "0-1".
    var characterId: String = ""
    var level: Int = 0
    var bestScore: Int = 0
    var attempts: Int = 0
    var totalMisses: Int = 0
    var lastPracticedAt: Date?
    var updatedAt: Date = Date()
    /// Last-write-wins timestamp for SyncKit conflict resolution.
    var syncModifiedAt: Date = Date()
    /// Opaque CloudKit system fields (record metadata) persisted by SyncKit.
    var cloudSystemFields: Data?

    init(characterId: String, ownerUserId: String = "") {
        self.characterId = characterId
        self.ownerUserId = ownerUserId
        self.updatedAt = Date.now
    }
}

/// Result of recording a completed trace, returned so sessions can show XP.
struct TraceCompletionOutcome: Equatable {
    let xpAwarded: Int
    let didPromote: Bool
    let newLevel: Int
}
