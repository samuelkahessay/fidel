// Fidel/Services/NextStepPlanner.swift
import Foundation

struct RecommendedSession: Equatable {
    enum Kind: Equatable { case newLesson(Int), resumeLesson(Int), reviews, allCaughtUp }
    let kind: Kind
    let reviewCount: Int
    let newCount: Int
    let estimatedMinutes: Int
    let heroAction: HeroAction
    let eyebrow: String
    let title: String
    let detail: String
}

/// Chooses the single best "do this now" session over the OPEN path.
/// Priority: due reviews (capped) -> resume in-progress lesson -> next new
/// lesson -> all caught up. This recommender is what makes a fully-open path
/// usable for beginners without re-introducing locks.
struct NextStepPlanner {
    /// Computes plan inputs from domain objects so the Learn tab and Today tab
    /// stay in sync. inProgressLessonId is the most recent started-but-not-completed lesson.
    func recommend(progress: UserProgress?, lessons: [Lesson], tier: DailyGoalTier, dueReviewCount: Int) -> RecommendedSession {
        let completed = Set(progress?.lessonsCompleted ?? [])
        let ordered = lessons.map(\.id).sorted()
        let inProgress = (progress?.lessonsInProgress ?? []).last { !completed.contains($0) }
        return plan(completedLessonIds: completed, inProgressLessonId: inProgress, tier: tier, dueReviewCount: dueReviewCount, orderedLessonIds: ordered)
    }

    func plan(completedLessonIds: Set<Int>,
              inProgressLessonId: Int?,
              tier: DailyGoalTier,
              dueReviewCount: Int,
              orderedLessonIds: [Int]) -> RecommendedSession {
        let reviews = min(dueReviewCount, tier.reviewCap)
        let nextNewId = orderedLessonIds.first { !completedLessonIds.contains($0) }

        if reviews > 0 {
            let hasNew = nextNewId != nil
            return RecommendedSession(
                kind: .reviews, reviewCount: reviews,
                newCount: hasNew ? tier.newCap : 0,
                estimatedMinutes: tier.estimatedMinutes,
                heroAction: .flashcards,
                eyebrow: "Recommended today",
                title: "Review \(reviews) word\(reviews == 1 ? "" : "s")",
                detail: hasNew ? "then start something new" : "keep your memory fresh")
        }
        if let resumeId = inProgressLessonId, !completedLessonIds.contains(resumeId) {
            return RecommendedSession(
                kind: .resumeLesson(resumeId), reviewCount: 0, newCount: tier.newCap,
                estimatedMinutes: tier.estimatedMinutes, heroAction: .lesson(resumeId),
                eyebrow: "Pick up where you left off", title: "Continue your lesson",
                detail: "~\(tier.estimatedMinutes) min")
        }
        if let newId = nextNewId {
            return RecommendedSession(
                kind: .newLesson(newId), reviewCount: 0, newCount: tier.newCap,
                estimatedMinutes: tier.estimatedMinutes, heroAction: .lesson(newId),
                eyebrow: "Recommended today", title: "Start a new lesson",
                detail: "~\(tier.estimatedMinutes) min · \(tier.newCap) new")
        }
        return RecommendedSession(
            kind: .allCaughtUp, reviewCount: 0, newCount: 0,
            estimatedMinutes: tier.estimatedMinutes, heroAction: .flashcards,
            eyebrow: "You're all caught up", title: "Free practice",
            detail: "Review anything you like")
    }
}
