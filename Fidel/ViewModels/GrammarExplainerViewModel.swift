import Foundation

/// Drives the Grammar reference ("teach-first" explainer) surface: the bundled
/// grammar patterns grouped by their grammar category, each introduced by a short
/// English explanation of the rule. Amharic is highly inflected (person, gender,
/// number, tense, negation), which learners cannot infer from substitution drills
/// alone — this is the explicit teaching surface the practice drills lacked.
///
/// Content is the existing, vetted `patterns.json` (structure, template, worked
/// examples) plus **English-only** teaching blurbs — no new Amharic is authored,
/// so this stays within the app's editorial/import gate.
@MainActor
@Observable
final class GrammarExplainerViewModel {

    /// One grammar topic: a category of patterns with an English rule summary.
    struct Topic: Identifiable, Hashable {
        let id: String  // the pattern category string
        let title: String  // human-friendly title
        let blurb: String  // English explanation of the rule
        let patterns: [Pattern]  // the vetted patterns in this category
        var unit: Int { patterns.map { $0.unit }.min() ?? 0 }
    }

    private let lessonRepository: LessonRepositoryProtocol

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    /// Topics built by grouping patterns on their `category`, ordered by the
    /// lowest grammar unit in each group so the sequence follows the curriculum
    /// (present tense → possessives → questions → … → ability & preference).
    var topics: [Topic] {
        let grouped = Dictionary(grouping: lessonRepository.getPatterns()) { $0.category }
        return grouped.map { category, patterns in
            Topic(
                id: category,
                title: Self.title(for: category),
                blurb: Self.blurb(for: category),
                patterns: patterns.sorted { $0.id < $1.id }
            )
        }
        .sorted { ($0.unit, $0.title) < ($1.unit, $1.title) }
    }

    // MARK: - Presentation

    /// Title-cases the SCREAMING category labels used in the data
    /// (e.g. "BASIC PRESENT TENSE (Subject + Verb)" → "Basic Present Tense").
    private static func title(for category: String) -> String {
        let base = category.split(separator: "(").first.map(String.init) ?? category
        return
            base
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    /// English-only rule summaries, keyed by the data's category strings. The
    /// concrete Amharic forms are shown from each pattern's vetted `structure`
    /// and `examples`; these blurbs never introduce new Amharic.
    private static func blurb(for category: String) -> String {
        blurbs[category] ?? "Study the sentence patterns below. Watch how the Amharic changes across the worked examples."
    }

    private static let blurbs: [String: String] = [
        "BASIC PRESENT TENSE (Subject + Verb)":
            "Amharic “to be” changes its ending for each subject — I, you (masculine), you (feminine), he, she, we, and they each take a different form. The describing word (an adjective or state) sits in the middle. Compare the endings across the examples to see the pattern.",
        "POSSESSIVE PHRASES":
            "Possession is built with a possessive marker before the noun (“my”, “your”, and so on). Notice how the marker changes with the owner while the noun itself stays the same.",
        "BASIC QUESTIONS":
            "Questions are formed with a question word (who, what, where, when, how much). Word order stays close to a statement — the question word and intonation do the work.",
        "BASIC RESPONSES":
            "Short, high-frequency answers — yes, no, agreement, and polite acknowledgements — that keep a conversation moving.",
        "COMMON EXPRESSIONS":
            "Fixed everyday expressions for wants, thanks, and social situations. Learn these as whole chunks rather than word by word.",
        "PAST TENSE":
            "The past (perfect) is built on the verb stem with a person ending — a different suffix for I / you / he / she / we / they. Track how the ending shifts per subject in the examples.",
        "FUTURE TENSE":
            "The future/present is built with a subject prefix on the verb plus an auxiliary ending. The prefix marks who does the action; the ending completes the tense.",
        "NEGATION":
            "Negation wraps the verb: a marker attaches before it and another after it. The same word turns positive → negative by adding this frame — watch the beginning and end of the verb.",
        "COMMANDS & REQUESTS":
            "Commands change with who you address — masculine, feminine, or plural take different endings — and polite requests add a “please” word. Choose the form that matches the listener.",
        "ABILITY & PREFERENCE":
            "Expressing what you can do, want, or prefer uses helper verbs before or around the main verb. These let you move from stating facts to expressing intentions and choices.",
    ]
}
