import Foundation
import os

class LLMService: ObservableObject {
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    func processJournalEntry(text: String) async throws -> AIResponse {
        Logger.ai.info("Starting AI processing for text length: \(text.count)")
        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            Logger.ai.error("Missing API Key")
            throw LLMError.missingAPIKey
        }

        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        // Prompt Engineering
        let systemPrompt = """
        You are an intelligent journaling assistant. Your job is to analyze the user's stream-of-consciousness entry and extract structured insights.

        Output valid JSON only matching this schema:
        {
          "summary": "2-3 sentences summarizing the entry",
          "insights": ["List of key realizations or patterns"],
          "action_items": ["List of actionable tasks mentioned or implied"],
          "tags": ["List of 3-5 relevant hashtags"]
        }
        """

        let userPrompt = "Date: \(dateString)\n\nJournal Entry:\n\(text)"

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Minimal cost, high speed
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        Logger.ai.debug("Sending request to OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode != 200 {
            // Basic error description
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.ai.error("API Error: \(statusCode) - \(body)")
            throw LLMError.apiError(statusCode: statusCode, message: body)
        }

        // Parse OpenAI Response
        // Structure: choices[0].message.content -> JSON String -> AIResponse
        struct OpenAIChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        do {
            let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let jsonString = chatResponse.choices.first?.message.content,
                  let jsonData = jsonString.data(using: .utf8) else {
                Logger.ai.error("Invalid response format from OpenAI")
                throw LLMError.invalidResponse
            }

            let aiResponse = try JSONDecoder().decode(AIResponse.self, from: jsonData)
            Logger.ai.notice("Successfully parsed AI response.")
            return aiResponse
        } catch {
            Logger.ai.fault("JSON Decoding Error: \(error.localizedDescription)")
            throw error
        }
    }
}

enum LLMError: Error {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var localizedDescription: String {
        switch self {
        case .missingAPIKey: return "Please add your OpenAI API Key in Settings."
        case .invalidResponse: return "The AI returned an invalid response."
        case .apiError(let code, let msg): return "AI Error (\(code)): \(msg)"
        }
    }
}
