import Foundation

// MARK: - AI Service Protocol

protocol SelamAIServiceProtocol {
    func sendMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) async throws -> SelamChatResponse
    
    func streamMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) -> AsyncThrowingStream<SelamStreamToken, Error>
}

// MARK: - OpenRouter Configuration

struct OpenRouterConfig {
    static let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    static let model = "anthropic/claude-3.5-sonnet"
    
    static var apiKey: String {
        if let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String,
           !key.isEmpty, key != "$(OPENROUTER_API_KEY)" {
            return key
        }
        return ""
    }
}

// MARK: - OpenRouter Service Implementation

final class SelamAPIService: SelamAIServiceProtocol {
    private let session: URLSession
    private let systemPrompt: String
    
    init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: sessionConfig)
        
        self.systemPrompt = """
        You are Selam (ሰላም), an expert Amharic language tutor for the Fidel iOS app. You are:
        - Patient, encouraging, and never make users feel bad about mistakes
        - Knowledgeable about Ethiopian culture, customs, and etiquette
        - Concise (2-3 paragraphs max unless explaining complex grammar)
        - Natural with Amharic script, always providing transliterations in parentheses

        When responding:
        - Use Amharic script naturally, followed by transliteration in parentheses
        - Give specific examples with context
        - Celebrate wins and progress
        - Offer gentle corrections with explanations
        - At the end of responses, suggest 2-3 follow-up actions the user might want

        Format examples like:
        ጤና ይስጥልኝ (t'ena yist'illiany) - Hello

        You have access to the user's learning progress. Reference their:
        - Completed lessons and patterns learned
        - Vocabulary they've mastered
        - Current streak and level
        - Areas where they may be struggling
        """
    }
    
    func sendMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) async throws -> SelamChatResponse {
        let messages = buildMessages(message: message, context: context, history: history, entryContext: entryContext, settings: settings)
        
        let requestBody: [String: Any] = [
            "model": OpenRouterConfig.model,
            "messages": messages,
            "max_tokens": 1024,
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: OpenRouterConfig.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(OpenRouterConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Fidel Amharic Learning App", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SelamAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw SelamAPIError.rateLimitExceeded
            }
            throw SelamAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageObj = firstChoice["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw SelamAPIError.invalidResponse
        }
        
        let suggestedActions = extractSuggestedActions(from: content)
        
        return SelamChatResponse(
            message: content,
            suggestedActions: suggestedActions,
            shouldShowConfetti: false
        )
    }
    
    func streamMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) -> AsyncThrowingStream<SelamStreamToken, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let messages = buildMessages(message: message, context: context, history: history, entryContext: entryContext, settings: settings)
                    
                    let requestBody: [String: Any] = [
                        "model": OpenRouterConfig.model,
                        "messages": messages,
                        "max_tokens": 1024,
                        "temperature": 0.7,
                        "stream": true
                    ]
                    
                    var request = URLRequest(url: OpenRouterConfig.baseURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(OpenRouterConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("Fidel Amharic Learning App", forHTTPHeaderField: "X-Title")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw SelamAPIError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 429 {
                            throw SelamAPIError.rateLimitExceeded
                        }
                        throw SelamAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                    
                    var fullContent = ""
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        
                        if jsonString == "[DONE]" {
                            let suggestedActions = extractSuggestedActions(from: fullContent)
                            continuation.yield(SelamStreamToken(
                                content: nil,
                                suggestedActions: suggestedActions,
                                done: true
                            ))
                            break
                        }
                        
                        guard let data = jsonString.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let firstChoice = choices.first,
                              let delta = firstChoice["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        
                        fullContent += content
                        continuation.yield(SelamStreamToken(
                            content: content,
                            suggestedActions: nil,
                            done: false
                        ))
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func buildMessages(
        message: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) -> [[String: String]] {
        var messages: [[String: String]] = []
        
        var systemContent = systemPrompt
        systemContent += "\n\n--- USER CONTEXT ---\n"
        systemContent += "Level: \(context.level)\n"
        systemContent += "Current streak: \(context.currentStreak) days\n"
        systemContent += "Total XP: \(context.totalXP)\n"
        systemContent += "Lessons completed: \(context.lessonsCompleted.count)\n"
        systemContent += "Vocabulary mastered: \(context.vocabularyMastered.count) words\n"
        
        if !context.weakAreas.isEmpty {
            systemContent += "Areas needing work: \(context.weakAreas.joined(separator: ", "))\n"
        }
        
        if let entryPrompt = entryContext?.toPromptContext() {
            systemContent += "\n--- ENTRY CONTEXT ---\n\(entryPrompt)\n"
        }
        
        let langPref = settings.languagePreference
        if langPref == .amharic {
            systemContent += "\nRespond primarily in Amharic with English translations."
        } else if langPref == .english {
            systemContent += "\nRespond primarily in English with Amharic examples."
        }
        
        messages.append(["role": "system", "content": systemContent])
        
        for historyItem in history.suffix(10) {
            messages.append(["role": historyItem.role, "content": historyItem.content])
        }
        
        messages.append(["role": "user", "content": message])
        
        return messages
    }
    
    private func extractSuggestedActions(from content: String) -> [String] {
        let lines = content.components(separatedBy: "\n")
        var actions: [String] = []
        
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var action: String? = nil
            
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                action = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if let range = trimmed.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                action = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            
            if let action = action, action.count > 5 && action.count < 80 {
                actions.insert(action, at: 0)
            }
            
            if actions.count >= 3 { break }
        }
        
        if actions.isEmpty {
            return ["Ask another question", "Practice vocabulary", "Try a quiz"]
        }
        
        return actions
    }
}

// MARK: - Mock Service for Development/Testing

final class MockSelamAIService: SelamAIServiceProtocol {
    var mockDelay: TimeInterval = 1.0
    
    func sendMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) async throws -> SelamChatResponse {
        try await Task.sleep(for: .seconds(mockDelay))
        return generateMockResponse(for: message, context: context)
    }
    
    func streamMessage(
        _ message: String,
        conversationId: String,
        context: SelamContext,
        history: [SelamHistoryMessage],
        entryContext: SelamEntryContext?,
        settings: SelamCoachingSettings
    ) -> AsyncThrowingStream<SelamStreamToken, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let response = generateMockResponse(for: message, context: context)
                let words = response.message.split(separator: " ")
                
                for (index, word) in words.enumerated() {
                    try? await Task.sleep(for: .milliseconds(50))
                    let isLast = index == words.count - 1
                    continuation.yield(SelamStreamToken(
                        content: String(word) + (isLast ? "" : " "),
                        suggestedActions: isLast ? response.suggestedActions : nil,
                        done: isLast
                    ))
                }
                continuation.finish()
            }
        }
    }
    
    private func generateMockResponse(for message: String, context: SelamContext) -> SelamChatResponse {
        let lowercased = message.lowercased()
        
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return SelamChatResponse(
                message: "ሰላም! (selam!) Welcome! I'm so happy to help you learn Amharic.\n\nThe most common greeting is ጤና ይስጥልኝ (t'ena yist'illiany), meaning \"May God give you health.\"\n\nYou've completed \(context.lessonsCompleted.count) lessons - great progress! 🎉",
                suggestedActions: ["Teach me more greetings", "How do I say goodbye?", "Practice a conversation"],
                shouldShowConfetti: false
            )
        }
        
        return SelamChatResponse(
            message: "That's a great question! Based on your progress (Level \(context.level), \(context.currentStreak) day streak), you're doing wonderfully.\n\nHow can I help you today?",
            suggestedActions: ["Help with vocabulary", "Grammar question", "Practice speaking"],
            shouldShowConfetti: false
        )
    }
}

// MARK: - Errors

enum SelamAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case rateLimitExceeded
    case networkError(Error)
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error (code: \(code))"
        case .rateLimitExceeded:
            return "Rate limit reached. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .missingAPIKey:
            return "API key not configured"
        }
    }
}
