import Foundation
import FoundationModels
import os

// MARK: - AI Service Protocol

protocol SelamAIServiceProtocol {
    func streamMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) -> AsyncThrowingStream<SelamStreamToken, Error>
}

// MARK: - Feature flag

/// Selam runs only on Apple's on-device model. Devices without Apple
/// Intelligence (or with it turned off or still downloading) never see Selam.
enum SelamAvailability {
    static var isEnabled: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
}

// MARK: - On-device service

/// Selam backed by Apple's Foundation Models framework. The model does not
/// support Amharic, so it explains in English and must pull every Amharic word
/// from Fidel's curriculum through the lookup tools.
final class OnDeviceSelamService: SelamAIServiceProtocol {
    private let knowledge: SelamKnowledge

    init(knowledge: SelamKnowledge = SelamKnowledge()) {
        self.knowledge = knowledge
    }

    static let baseInstructions = """
    You are Selam, a patient and encouraging Amharic tutor inside the Fidel app. Explain in English.

    Rules for Amharic:
    - NEVER write Amharic script or transliteration from memory.
    - To show any Amharic word or phrase, call lookupWords with the English meaning and copy the result exactly, as: Amharic (transliteration) - English.
    - For grammar, call lookupGrammar. For the vowel forms of a letter, call lookupFidelRow.
    - If a lookup returns nothing, say the Fidel curriculum doesn't cover that yet. Do not guess.

    Keep answers short: at most two short paragraphs.
    End with exactly three follow-up questions the learner could ask next, each on its own line starting with "- ".
    """

    func streamMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) -> AsyncThrowingStream<SelamStreamToken, Error> {
        let instructions = Self.instructions(context: context, history: history, entryContext: entryContext)
        let tools: [any Tool] = [
            LookupWordsTool(knowledge: knowledge),
            LookupGrammarTool(knowledge: knowledge),
            LookupFidelRowTool(knowledge: knowledge),
        ]

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(tools: tools, instructions: instructions)
                    var emitted = ""
                    for try await snapshot in session.streamResponse(to: message) {
                        let full = snapshot.content
                        if full.hasPrefix(emitted) {
                            let delta = String(full.dropFirst(emitted.count))
                            if !delta.isEmpty {
                                continuation.yield(SelamStreamToken(content: delta, suggestedActions: nil, done: false))
                            }
                        }
                        emitted = full
                    }
                    continuation.yield(SelamStreamToken(
                        content: nil,
                        suggestedActions: SelamSuggestions.extract(from: emitted),
                        done: true
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: SelamError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func instructions(
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?
    ) -> String {
        var text = baseInstructions
        text += "\n\nLearner: level \(context.level), \(context.currentStreak)-day streak, "
        text += "\(context.lessonsCompleted.count) lessons completed."
        if let entry = entryContext?.toPromptContext() {
            text += "\n\(entry)"
        }
        // The on-device context window is small; carry only the last few turns.
        let recent = history.suffix(4)
        if !recent.isEmpty {
            text += "\n\nRecent conversation:\n"
            text += recent.map { "\($0.role): \($0.content.prefix(400))" }.joined(separator: "\n")
        }
        return text
    }
}

// MARK: - Tools

struct LookupWordsTool: Tool {
    let knowledge: SelamKnowledge
    let name = "lookupWords"
    let description = "Finds Amharic words and phrases in the Fidel curriculum by English meaning."

    @Generable
    struct Arguments {
        @Guide(description: "An English word or short phrase, e.g. 'water' or 'thank you'")
        var english: String
    }

    func call(arguments: Arguments) async throws -> String {
        let entries = knowledge.lookupWords(arguments.english)
        return entries.isEmpty
            ? "No match for '\(arguments.english)' in the Fidel curriculum."
            : SelamKnowledge.describe(entries)
    }
}

struct LookupGrammarTool: Tool {
    let knowledge: SelamKnowledge
    let name = "lookupGrammar"
    let description = "Finds Amharic grammar patterns with examples, by English topic keywords."

    @Generable
    struct Arguments {
        @Guide(description: "One or two English keywords, e.g. 'question' or 'past tense'")
        var topic: String
    }

    func call(arguments: Arguments) async throws -> String {
        let patterns = knowledge.lookupGrammar(arguments.topic)
        return patterns.isEmpty
            ? "No grammar pattern about '\(arguments.topic)' in the Fidel curriculum."
            : SelamKnowledge.describe(patterns)
    }
}

struct LookupFidelRowTool: Tool {
    let knowledge: SelamKnowledge
    let name = "lookupFidelRow"
    let description = "Returns the seven vowel forms of a Fidel letter."

    @Generable
    struct Arguments {
        @Guide(description: "A Fidel character, or its consonant sound in Latin letters, e.g. 'l'")
        var letter: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let row = knowledge.lookupFidelRow(arguments.letter) else {
            return "No Fidel row for '\(arguments.letter)'."
        }
        return SelamKnowledge.describe(row)
    }
}

// MARK: - Suggested follow-ups

enum SelamSuggestions {
    static let fallback = ["How do I say thank you?", "Teach me a greeting", "Show me the letter ለ"]

    static func extract(from content: String) -> [String] {
        var actions: [String] = []
        for line in content.components(separatedBy: "\n").reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var action: String?
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                action = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if let range = trimmed.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                action = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            if let action, action.count > 5, action.count < 80 {
                actions.insert(action, at: 0)
            }
            if actions.count >= 3 { break }
        }
        return actions.isEmpty ? fallback : actions
    }
}

// MARK: - Errors

enum SelamError: LocalizedError {
    private static let logger = Logger(subsystem: "dev.skahessay.learnamharic", category: "selam")

    case unavailable
    case unsupportedLanguage
    case tooLong
    case declined
    case failed(String)

    init(_ error: Error) {
        Self.logger.error("Selam generation failed: \(String(describing: error), privacy: .public)")
        guard let generation = error as? LanguageModelSession.GenerationError else {
            self = .failed(error.localizedDescription)
            return
        }
        switch generation {
        case .assetsUnavailable: self = .unavailable
        case .unsupportedLanguageOrLocale: self = .unsupportedLanguage
        case .exceededContextWindowSize: self = .tooLong
        case .guardrailViolation, .refusal: self = .declined
        default: self = .failed(generation.localizedDescription)
        }
    }

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Selam needs Apple Intelligence, which isn't ready on this device right now."
        case .unsupportedLanguage:
            return "Ask Selam in English. It will look up the Amharic for you."
        case .tooLong:
            return "This conversation got too long. Start a new one to keep going."
        case .declined:
            return "Selam can't help with that one. Try asking about Amharic words, grammar or letters."
        case .failed:
            return "Selam couldn't answer right now. Try again in a moment."
        }
    }
}
