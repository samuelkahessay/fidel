// Fidel/Models/DailyGoalTier.swift
import Foundation

/// The learner-chosen pace. Single control that sizes both the daily
/// recommendation (NextStepPlanner) and the tracing session. Replaces the
/// hardcoded 8-char session; `.regular` preserves the legacy default exactly.
enum DailyGoalTier: String, CaseIterable, Codable, Identifiable {
    case casual, regular, serious, intense

    var id: String { rawValue }

    static let `default`: DailyGoalTier = .regular

    /// Max new items introduced in one recommended session.
    var newCap: Int {
        switch self { case .casual: 3; case .regular: 5; case .serious: 8; case .intense: 12 }
    }
    /// Max spaced-repetition reviews surfaced in one session (prevents backlog overwhelm).
    var reviewCap: Int {
        switch self { case .casual: 10; case .regular: 15; case .serious: 20; case .intense: 30 }
    }
    /// Number of characters in a "Practice Fidel" tracing session.
    var tracingSessionSize: Int {
        switch self { case .casual: 5; case .regular: 8; case .serious: 12; case .intense: 16 }
    }
    var estimatedMinutes: Int {
        switch self { case .casual: 2; case .regular: 5; case .serious: 10; case .intense: 15 }
    }
    /// Suggested daily-XP-ring target when the learner first picks this tier.
    var suggestedDailyXP: Int {
        switch self { case .casual: 10; case .regular: 20; case .serious: 30; case .intense: 50 }
    }
    var displayName: String {
        switch self { case .casual: "Casual"; case .regular: "Regular"; case .serious: "Serious"; case .intense: "Intense" }
    }
    var subtitle: String { "~\(estimatedMinutes) min · \(newCap) new" }
}
