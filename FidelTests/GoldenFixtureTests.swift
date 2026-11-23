import SwiftData
import XCTest

@testable import Fidel___Learn_Amharic

/// Golden fixtures shared with the web app (web/tests/unit/golden.test.ts).
///
/// Each fixture holds inputs and the outputs the Swift implementation produces
/// for them. By default this test recomputes the outputs and fails on any
/// difference, so a behaviour change on either platform fails CI until both
/// agree. Run with FIDEL_WRITE_GOLDEN=1 to regenerate after an intended change:
///
///     xcodebuild test ... -only-testing:FidelTests/GoldenFixtureTests TEST_RUNNER_FIDEL_WRITE_GOLDEN=1
@MainActor
final class GoldenFixtureTests: XCTestCase {
    private static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Golden")
    private var writing: Bool { ProcessInfo.processInfo.environment["FIDEL_WRITE_GOLDEN"] == "1" }

    // MARK: - Spaced repetition

    func testFSRS() throws {
        let states: [(Double, Double)] = [(0, 0), (0.4, 5.0), (3.17, 5.3), (15.7, 2.1), (100, 8.5)]
        var cases: [[String: Any]] = []
        for rating in [ReviewRating.again, .hard, .good, .easy] {
            for (stability, difficulty) in states {
                for elapsed in [0.0, 1, 3, 10, 45] {
                    let r = FSRSAlgorithm.calculateNextReview(
                        rating: rating, currentStability: stability, currentDifficulty: difficulty, elapsedDays: elapsed)
                    cases.append([
                        "rating": rating.rawValue, "stability": stability, "difficulty": difficulty, "elapsedDays": elapsed,
                        "expected": ["interval": r.newInterval, "stability": r.newStability, "difficulty": r.newDifficulty],
                    ])
                }
            }
        }
        try check("fsrs", ["cases": cases])
    }

    // MARK: - Recommendation

    func testPlanner() throws {
        let ordered = [1, 2, 3, 4, 5, 6, 7, 8]
        let inputs: [([Int], Int?, DailyGoalTier, Int)] = [
            ([], nil, .regular, 0), ([], nil, .casual, 4), ([1, 2], 3, .regular, 0), ([1], 1, .serious, 0),
            (ordered, nil, .intense, 0), (ordered, nil, .regular, 40), ([1, 2, 3], nil, .casual, 1), ([], 5, .intense, 0),
        ]
        let cases: [[String: Any]] = inputs.map { completed, inProgress, tier, due in
            let s = NextStepPlanner().plan(
                completedLessonIds: Set(completed), inProgressLessonId: inProgress, tier: tier,
                dueReviewCount: due, orderedLessonIds: ordered)
            var kind = ""
            var lessonId: Any = NSNull()
            switch s.kind {
            case .newLesson(let id):
                kind = "newLesson"
                lessonId = id
            case .resumeLesson(let id):
                kind = "resumeLesson"
                lessonId = id
            case .reviews: kind = "reviews"
            case .allCaughtUp: kind = "allCaughtUp"
            }
            return [
                "input": [
                    "completedLessonIds": completed, "inProgressLessonId": inProgress as Any? ?? NSNull(),
                    "tier": tier.rawValue, "dueReviewCount": due, "orderedLessonIds": ordered,
                ],
                "expected": [
                    "kind": kind, "lessonId": lessonId, "reviewCount": s.reviewCount, "newCount": s.newCount,
                    "estimatedMinutes": s.estimatedMinutes, "eyebrow": s.eyebrow, "title": s.title, "detail": s.detail,
                ],
            ]
        }
        try check("planner", ["cases": cases])
    }

    // MARK: - Lessons and mastery

    func testLessonsAndMastery() throws {
        let lessons = LessonRepository.shared.getLessons()
        let curriculum = CurriculumService.shared
        var lessonRows: [[String: Any]] = []
        var masteryCases: [[String: Any]] = []
        for lesson in lessons {
            let itemIds = lesson.vocabulary.map(\.id) + lesson.phrases.map { String($0.id) }
            let charIds = curriculum.characterIds(in: lesson)
            lessonRows.append([
                "id": lesson.id,
                "patternIds": lesson.patterns.map(\.id),
                "vocabularyIds": lesson.vocabulary.map(\.id),
                "phraseIds": lesson.phrases.map(\.id),
                "characterIds": charIds,
            ])
            for share in [0.0, 0.3, 0.6, 0.85, 1.0] {
                let learned = Array(itemIds.prefix(Int((Double(itemIds.count) * share).rounded())))
                let recognized = Array(charIds.prefix(Int((Double(charIds.count) * share).rounded())))
                let m = curriculum.mastery(for: lesson, learnedItemIds: Set(learned), recognizedCharIds: Set(recognized))
                masteryCases.append([
                    "lessonId": lesson.id, "learnedItemIds": learned, "recognizedCharIds": recognized,
                    "expected": ["tier": m.tier.label, "fraction": m.fraction],
                ])
            }
        }
        try check("lessons", ["lessons": lessonRows, "mastery": masteryCases])
    }

    // MARK: - Streaks and daily XP

    func testProgressRules() throws {
        typealias Step = (op: String, amount: Int, at: String)
        let scenarios: [(name: String, start: [String: Any], steps: [Step])] = [
            ("first practice", [:], [("addXP", 10, "2026-03-04T09:00")]),
            ("next day continues the streak", [:], [("addXP", 10, "2026-03-04T09:00"), ("addXP", 5, "2026-03-05T21:30")]),
            ("same day twice", [:], [("addXP", 10, "2026-03-04T09:00"), ("addXP", 5, "2026-03-04T23:59")]),
            (
                "one missed day spends a freeze", [:],
                [("addXP", 10, "2026-03-02T09:00"), ("addXP", 10, "2026-03-03T09:00"), ("addXP", 10, "2026-03-05T09:00")]
            ),
            (
                "one missed day without a freeze resets",
                [
                    "streakFreezesAvailable": 0, "lastFreezeGrantWeek": 202610, "currentStreak": 4, "longestStreak": 4,
                    "lastPracticeDate": "2026-03-03T09:00",
                ],
                [("addXP", 10, "2026-03-05T09:00")]
            ),
            ("three missed days resets", [:], [("addXP", 10, "2026-03-02T09:00"), ("addXP", 10, "2026-03-06T09:00")]),
            (
                "new week grants a freeze, capped at two", [:],
                [
                    ("addXP", 1, "2026-03-07T09:00"), ("addXP", 1, "2026-03-08T09:00"), ("addXP", 1, "2026-03-15T09:00"),
                    ("addXP", 1, "2026-03-22T09:00"),
                ]
            ),
            ("year boundary week", [:], [("addXP", 1, "2026-12-31T12:00"), ("addXP", 1, "2027-01-01T12:00")]),
            (
                "daily XP resets on a new day", [:],
                [("addXP", 30, "2026-03-04T09:00"), ("addXP", 5, "2026-03-04T18:00"), ("addXP", 7, "2026-03-05T08:00")]
            ),
            (
                "lesson started then completed", [:],
                [("markLessonStarted", 3, "2026-03-04T09:00"), ("completeLesson", 3, "2026-03-04T09:30")]
            ),
        ]
        var cases: [[String: Any]] = []
        for scenario in scenarios {
            let p = Self.progress(from: scenario.start)
            for step in scenario.steps {
                let now = Self.local(step.at)
                switch step.op {
                case "addXP": p.addXP(step.amount, now: now)
                case "markLessonStarted": p.markLessonStarted(step.amount)
                case "completeLesson":
                    p.lessonsCompleted.append(step.amount)
                    p.addXP(25, now: now)
                    p.lessonsInProgress.removeAll { $0 == step.amount }
                default: XCTFail("unknown op \(step.op)")
                }
            }
            cases.append([
                "name": scenario.name,
                "start": scenario.start,
                "steps": scenario.steps.map { ["op": $0.op, "value": $0.amount, "at": $0.at] },
                "expected": [
                    "totalXP": p.totalXP, "todayXP": p.todayXP, "currentStreak": p.currentStreak,
                    "longestStreak": p.longestStreak, "streakFreezesAvailable": p.streakFreezesAvailable,
                    "weeklyStreakCount": p.weeklyStreakCount, "lastFreezeGrantWeek": p.lastFreezeGrantWeek,
                    "lessonsCompleted": p.lessonsCompleted, "lessonsInProgress": p.lessonsInProgress,
                ],
            ])
        }
        try check("progress", ["cases": cases])
    }

    // MARK: - Backup import

    func testBackupImport() throws {
        let backups: [(name: String, local: [String: Any], file: [String: Any])] = [
            ("into an empty device", [:], Self.backupFile(xp: 340, lessons: [1, 2], inProgress: [3], cards: [("Family-አባት", 2)])),
            (
                "merges with local progress", ["totalXP": 500, "lessonsCompleted": [4], "lessonsInProgress": [1]],
                Self.backupFile(xp: 340, lessons: [1, 2], inProgress: [3], cards: [("Family-አባት", 2)])
            ),
            (
                "fewer repetitions never overwrite a card", ["cards": [("Family-አባት", 5)]],
                Self.backupFile(xp: 10, lessons: [], inProgress: [], cards: [("Family-አባት", 2), ("Family-እናት", 1)])
            ),
        ]
        var cases: [[String: Any]] = []
        for backup in backups {
            let container = try Self.container()
            let context = container.mainContext
            let suite = "golden.\(UUID().uuidString)"
            let settings = AppSettingsStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
            let p = UserProgress(ownerUserId: LocalLearner.userId)
            if let v = backup.local["totalXP"] as? Int { p.totalXP = v }
            if let v = backup.local["lessonsCompleted"] as? [Int] { p.lessonsCompleted = v }
            if let v = backup.local["lessonsInProgress"] as? [Int] { p.lessonsInProgress = v }
            if !backup.local.isEmpty { context.insert(p) }
            for (itemId, reps) in (backup.local["cards"] as? [(String, Int)]) ?? [] {
                let card = FlashcardProgress(itemId: itemId, itemType: "vocabulary", ownerUserId: LocalLearner.userId)
                card.repetitions = reps
                context.insert(card)
            }
            let data = try JSONSerialization.data(withJSONObject: backup.file, options: [.sortedKeys])
            try ProgressExportService(modelContext: context, settingsStore: settings).importData(data)

            let merged = try context.fetch(FetchDescriptor<UserProgress>()).first
            let cards = try context.fetch(FetchDescriptor<FlashcardProgress>()).sorted { $0.itemId < $1.itemId }
            var local = backup.local
            local["cards"] = ((backup.local["cards"] as? [(String, Int)]) ?? []).map { ["itemId": $0.0, "repetitions": $0.1] }
            cases.append([
                "name": backup.name,
                "local": local,
                "backup": backup.file,
                "expected": [
                    "totalXP": merged?.totalXP ?? 0,
                    "lessonsCompleted": merged?.lessonsCompleted ?? [],
                    "lessonsInProgress": merged?.lessonsInProgress ?? [],
                    "cards": cards.map { ["itemId": $0.itemId, "repetitions": $0.repetitions, "interval": $0.interval] },
                    "dailyGoalTier": settings.dailyGoalTier.rawValue,
                ],
            ])
            UserDefaults().removePersistentDomain(forName: suite)
        }
        try check("backup", ["cases": cases])
    }

    // MARK: - Tracing

    func testTraceReplays() throws {
        let canvas = TracingLayout.canvasSize
        let chart = LessonRepository.shared.getFidelChart().flatMap { $0 }
        var widths: [String: Double] = [:]
        for c in chart {
            widths[c.id] = Double(PathExtractor.shared.glyphStrokeWidth(for: c.character, size: canvas))
        }

        let sample = [
            "0-1", "0-4", "1-1", "2-6", "3-2", "5-7", "7-1", "9-3", "12-5", "15-1", "18-6", "21-2", "24-4", "27-7", "30-3", "33-1",
        ]
        var characters: [[String: Any]] = []
        for id in sample {
            guard let strokeData = StrokeDataRepository.shared.getStrokeData(for: id),
                let c = chart.first(where: { $0.id == id })
            else { continue }
            let engine = TraceEngine()
            engine.configure(
                strokes: strokeData.strokes, canvasSize: canvas, glyphStrokeWidth: widths[id] ?? 0,
                recordingGlyphScale: TracingSessionViewModel.recordingGlyphScale)
            let strokes = engine.strokes
            var replays: [[String: Any]] = []
            for scenario in ["exact", "offset12", "offset70", "half", "farStart"] {
                let touches = Self.touches(for: strokes, scenario: scenario)
                let result = Self.replay(touches, strokes: strokeData.strokes, width: widths[id] ?? 0, canvas: canvas)
                replays.append(["scenario": scenario, "touches": touches, "expected": result])
            }
            characters.append([
                "id": id, "character": c.character, "glyphStrokeWidth": widths[id] ?? 0,
                "strokes": strokes.map {
                    [
                        "totalLength": Double($0.totalLength), "corridorRadius": Double($0.corridorRadius), "isDot": $0.isDot,
                        "polylineCount": $0.polyline.count,
                        "start": [Double($0.startPoint.x), Double($0.startPoint.y)],
                        "end": [Double($0.endPoint.x), Double($0.endPoint.y)],
                    ]
                },
                "replays": replays,
            ])
        }
        try check("trace", ["canvas": [canvas.width, canvas.height], "glyphStrokeWidths": widths, "characters": characters])
    }

    /// Deterministic touch sequences along the traceable strokes, as [phase, x, y, t].
    private static func touches(for strokes: [TraceableStroke], scenario: String) -> [[Any]] {
        var out: [[Any]] = []
        var t = 0.0
        func add(_ phase: String, _ p: CGPoint) {
            out.append([phase, (Double(p.x) * 1000).rounded() / 1000, (Double(p.y) * 1000).rounded() / 1000, t])
            t += 0.016
        }
        let attempts = scenario == "offset70" ? 2 : 1
        for stroke in strokes {
            for _ in 0..<attempts {
                let offset: CGFloat = scenario == "offset12" ? 12 : scenario == "offset70" ? 70 : 0
                let points = stride(from: 0, to: stroke.polyline.count, by: 4).map { i -> CGPoint in
                    let p = stroke.polyline[i]
                    let tangent = TraceGeometry.tangent(at: stroke.cumulative[i], on: stroke)
                    return CGPoint(x: p.x - tangent.dy * offset, y: p.y + tangent.dx * offset)
                }
                let limit = scenario == "half" ? max(1, points.count / 2) : points.count
                let start = scenario == "farStart" ? CGPoint(x: stroke.startPoint.x + 120, y: stroke.startPoint.y + 120) : stroke.startPoint
                add("began", start)
                for p in points.prefix(limit) { add("moved", p) }
                add("ended", scenario == "half" ? points[limit - 1] : stroke.endPoint)
                t += 0.2
            }
        }
        return out
    }

    private static func replay(_ touches: [[Any]], strokes: [RecordedStroke], width: Double, canvas: CGSize) -> [String: Any] {
        let engine = TraceEngine()
        engine.configure(
            strokes: strokes, canvasSize: canvas, glyphStrokeWidth: width,
            recordingGlyphScale: TracingSessionViewModel.recordingGlyphScale)
        var events: [String] = []
        engine.onEvent = { events.append(Self.describe($0)) }
        for touch in touches {
            guard let phase = touch[0] as? String, let x = touch[1] as? Double, let y = touch[2] as? Double,
                let t = touch[3] as? Double
            else { continue }
            let p = CGPoint(x: x, y: y)
            switch phase {
            case "began": engine.touchBegan(at: p, time: t)
            case "moved": engine.touchMoved(to: p, time: t)
            default: engine.touchEnded(at: p, time: t)
            }
            // The canvas would animate, then report back.
            switch engine.phase {
            case .snapping: engine.strokeMagnetSnapFinished()
            case .strokeComplete: engine.strokeSnapFinished()
            case .playingHint: engine.hintPlaybackFinished()
            default: break
            }
        }
        return ["events": events, "finalPhase": "\(engine.phase)", "activeStrokeIndex": engine.activeStrokeIndex]
    }

    // MARK: - Helpers

    private static func progress(from start: [String: Any]) -> UserProgress {
        let p = UserProgress()
        p.streakFreezesAvailable = start["streakFreezesAvailable"] as? Int ?? p.streakFreezesAvailable
        p.lastFreezeGrantWeek = start["lastFreezeGrantWeek"] as? Int ?? p.lastFreezeGrantWeek
        p.currentStreak = start["currentStreak"] as? Int ?? p.currentStreak
        p.longestStreak = start["longestStreak"] as? Int ?? p.longestStreak
        p.lastPracticeDate = (start["lastPracticeDate"] as? String).map(local)
        return p
    }

    private static func describe(_ event: TraceEngine.EngineEvent) -> String {
        switch event {
        case .strokeStarted(let i): "started:\(i)"
        case .strokeCompleted(let i): "completed:\(i)"
        case .miss(let i, let n): "miss:\(i):\(n)"
        case .hintAutoPlayed(let i): "hint:\(i)"
        case .characterCompleted(let s): "character:\(s.misses):\(s.hintsAutoPlayed)"
        }
    }

    private static func backupFile(xp: Int, lessons: [Int], inProgress: [Int], cards: [(String, Int)]) -> [String: Any] {
        [
            "version": 1,
            "exportedAt": "2026-03-04T09:00:00Z",
            "userProgress": [
                "totalXP": xp, "currentStreak": 2, "longestStreak": 5, "lastPracticeDate": "2026-03-04T09:00:00Z",
                "lessonsCompleted": lessons, "lessonsInProgress": inProgress, "patternsLearned": [String](),
                "vocabularyMastered": [String](), "conversationsPracticed": [Int](), "dailyGoal": 50, "todayXP": 0,
                "achievements": [String](), "fidelCharactersRecognized": ["0-1"], "charactersTraced": [String](),
                "currentStage": 0, "streakFreezesAvailable": 1, "weeklyStreakCount": 1, "lastFreezeGrantWeek": 202610,
            ],
            "flashcards": cards.map { id, reps in
                [
                    "itemId": id, "itemType": "vocabulary", "easeFactor": 2.5, "interval": reps * 3, "repetitions": reps,
                    "nextReviewDate": "2026-03-10T09:00:00Z", "lastReviewDate": "2026-03-04T09:00:00Z",
                    "stability": 3.17, "difficulty": 5.3, "lapses": 0,
                ] as [String: Any]
            },
            "settings": [
                "dailyXPGoal": 30, "preferredResponseLanguage": "mixed", "showsTransliteration": true,
                "autoPlaysPronunciation": true, "hapticsEnabled": true, "selectedReferenceTab": 0, "showsAITools": true,
                "onboardingComplete": true, "dailyGoalTier": "serious",
            ],
        ]
    }

    private static func container() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self, FlashcardProgress.self, SelamConversation.self, SelamMessage.self, CharacterTraceMastery.self,
        ])
        return try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }

    /// Local wall-clock time, "yyyy-MM-dd'T'HH:mm", in the device time zone (the web side does the same).
    static func local(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: string) ?? .distantPast
    }

    /// Writes the fixture when regenerating; otherwise compares with the committed copy.
    private func check(_ name: String, _ fixture: [String: Any]) throws {
        let url = Self.directory.appendingPathComponent("\(name).json")
        let data = try JSONSerialization.data(withJSONObject: fixture, options: [.prettyPrinted, .sortedKeys])
        if writing {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try data.write(to: url)
            return
        }
        let committed = try Data(contentsOf: url)
        let expected = try JSONSerialization.jsonObject(with: committed) as? NSDictionary
        let actual = try JSONSerialization.jsonObject(with: data) as? NSDictionary
        XCTAssertEqual(
            actual, expected,
            "\(name).json differs from the Swift implementation. Regenerate with FIDEL_WRITE_GOLDEN=1 if the change is intended.")
    }
}
