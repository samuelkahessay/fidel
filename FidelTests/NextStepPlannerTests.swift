// FidelTests/NextStepPlannerTests.swift
import XCTest

@testable import Fidel___Learn_Amharic

final class NextStepPlannerTests: XCTestCase {
    let planner = NextStepPlanner()
    let order = [1, 2, 3, 4, 5]

    func testFreshUserGetsFirstNewLesson() {
        let s = planner.plan(
            completedLessonIds: [], inProgressLessonId: nil,
            tier: .regular, dueReviewCount: 0, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .newLesson(1))
        XCTAssertEqual(s.heroAction, .lesson(1))
    }

    func testDueReviewsTakePriorityAndAreCapped() {
        let s = planner.plan(
            completedLessonIds: [1], inProgressLessonId: nil,
            tier: .regular, dueReviewCount: 100, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .reviews)
        XCTAssertEqual(s.reviewCount, DailyGoalTier.regular.reviewCap)  // 15
        XCTAssertEqual(s.heroAction, .flashcards)
    }

    func testResumeInProgressLessonWhenNoReviews() {
        let s = planner.plan(
            completedLessonIds: [1], inProgressLessonId: 2,
            tier: .regular, dueReviewCount: 0, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .resumeLesson(2))
        XCTAssertEqual(s.heroAction, .lesson(2))
    }

    func testAllCaughtUpWhenEverythingDoneAndNothingDue() {
        let s = planner.plan(
            completedLessonIds: Set(order), inProgressLessonId: nil,
            tier: .regular, dueReviewCount: 0, orderedLessonIds: order)
        XCTAssertEqual(s.kind, .allCaughtUp)
    }
}
