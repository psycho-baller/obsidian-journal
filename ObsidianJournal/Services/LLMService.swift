import Foundation
import os

// Models are defined in Shared/AIModels.swift

// MARK: - LLM Service

class LLMService: ObservableObject {
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    // MARK: - Template Population (New Primary Method)

    /// Analyzes a transcript and existing daily note template, returning structured updates.
    /// This is the core "template hydration" engine.
    func populateTemplate(transcript: String, existingNote: String, date: Date = Date()) async throws -> TemplatePopulationResponse {
        Logger.ai.info("Starting template population. Transcript: \(transcript.count) chars, Note: \(existingNote.count) chars")

        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let dateString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)

        // ═══════════════════════════════════════════════════════════════════════════════
        // SYSTEM PROMPT - The Heart of the Template Population Engine
        // ═══════════════════════════════════════════════════════════════════════════════
        let systemPrompt = """
        You are a precision data extraction agent for an Obsidian journaling system.

        ## Your Mission
        Analyze the user's voice transcript and intelligently populate sections of their existing daily note template. Extract ONLY information that is explicitly stated or directly implied in the transcript. Never fabricate, assume, or hallucinate data.

        ## Operating Principles
        1. **Grounding Rule**: Every value you output MUST be traceable to the transcript. If you cannot quote or paraphrase the source, output null for that field.
        2. **Respect the Template**: Only populate fields that exist in the provided template. Do not invent new sections.
        3. **Preserve Existing Data**: If a section already has content, use "append" to add new information. Use "replace" only if the transcript explicitly supersedes existing data.
        4. **Type Awareness**:
           - Text sections (## headings, bullet lists): Use "append" type with properly formatted markdown.
           - Metrics (numbers, scores, durations): Use "metric" type with the numeric value as a string.
           - Yes/No fields: Use "metric" type with "true"/"false".
        5. **Silence is Golden**: If the transcript contains no relevant information for a template section, DO NOT include that field in your output. An empty update list is valid.

        ## Output Schema (JSON)
        ```json
        {
          "updates": [
            {
              "field": "Exact heading or field name from template",
              "value": "The extracted content, formatted appropriately, or null if nothing applies",
              "updateType": "append" | "replace" | "metric"
            }
          ],
          "processing_notes": "Brief internal note about what was extracted (for debugging)"
        }
        ```

        ## Examples

        ### Example 1: Metrics Extraction
        **Template Section**: `Sleep Hours: `
        **Transcript**: "I got about 7 hours of sleep last night, felt pretty good."
        **Output**:
        ```json
        {"field": "Sleep Hours", "value": "7", "updateType": "metric"}
        ```

        ### Example 2: Text Section Append
        **Template Section**: `## Things I Learned`
        **Transcript**: "Today I realized that consistency beats intensity in habit formation."
        **Output**:
        ```json
        {"field": "## Things I Learned", "value": "- Consistency beats intensity in habit formation", "updateType": "append"}
        ```

        ### Example 3: No Relevant Data
        **Template Section**: `## Exercise Log`
        **Transcript**: "Had a really productive day at work coding."
        **Output**: Do not include "## Exercise Log" in the updates array.

        ### Example 4: Multiple Updates
        **Template**:
        ```
        Mood:
        ## Gratitude
        ## Tasks Completed
        ```
        **Transcript**: "Feeling great today, probably an 8 out of 10. Really grateful for the sunny weather. Finished the project proposal and sent it off."
        **Output**:
        ```json
        {
          "updates": [
            {"field": "Mood", "value": "8", "updateType": "metric"},
            {"field": "## Gratitude", "value": "- Sunny weather", "updateType": "append"},
            {"field": "## Tasks Completed", "value": "- Finished and sent project proposal", "updateType": "append"}
          ],
          "processing_notes": "Extracted mood score, gratitude item, and task completion."
        }
        ```

        ## Critical Reminders
        - **NEVER** make up information not in the transcript.
        - **ALWAYS** use the exact field name from the template.
        - Format bullet points with `- ` prefix for text sections.
        - For empty templates, focus on extracting whatever is mentioned.
        - Current date context: \(dateString)
        """

        // ═══════════════════════════════════════════════════════════════════════════════
        // USER PROMPT - Provides the Actual Data
        // ═══════════════════════════════════════════════════════════════════════════════
        let userPrompt = """
        ## EXISTING DAILY NOTE TEMPLATE
        ```markdown
        \(existingNote)
        ```

        ## VOICE TRANSCRIPT TO PROCESS
        ```
        \(transcript)
        ```

        Analyze the transcript above. According to the transcript, extract all relevant information that maps to sections in the template. Output valid JSON only.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2 // Low temperature for factual extraction
        ]

        return try await executeRequest(requestBody: requestBody, responseType: TemplatePopulationResponse.self)
    }

    // MARK: - Legacy Method (Simple Insight Extraction)

    /// Original method for backward compatibility - extracts insights without template context.
    func processJournalEntry(text: String) async throws -> AIResponse {
        Logger.ai.info("Starting legacy AI processing for text length: \(text.count)")

        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        let systemPrompt = """
        You are an intelligent journaling assistant. Your job is to analyze the user's stream-of-consciousness entry and extract structured insights.

        Output valid JSON only matching this schema:
        {
          "summary": "2-3 sentences summarizing the entry",
          "insights": ["List of key realizations or patterns"],
          "action_items": ["List of actionable tasks mentioned or implied"],
          "tags": ["List of 3-5 relevant hashtags without # symbol"]
        }

        Only include information explicitly stated or directly implied. Do not fabricate.
        """

        let userPrompt = "Date: \(dateString)\n\nJournal Entry:\n\(text)"

        let requestBody: [String: Any] = [
            "model": "gpt-5.2",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]

        return try await executeRequest(requestBody: requestBody, responseType: AIResponse.self)
    }

    // MARK: - Private Helpers

    private func executeRequest<T: Decodable>(requestBody: [String: Any], responseType: T.Type) async throws -> T {
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            throw LLMError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        Logger.ai.debug("Sending request to OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.ai.error("API Error: \(statusCode) - \(body)")
            throw LLMError.apiError(statusCode: statusCode, message: body)
        }

        do {
            let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let jsonString = chatResponse.choices.first?.message.content,
                  let jsonData = jsonString.data(using: .utf8) else {
                Logger.ai.error("Invalid response format from OpenAI")
                throw LLMError.invalidResponse
            }

            let result = try JSONDecoder().decode(T.self, from: jsonData)
            Logger.ai.notice("Successfully parsed AI response of type \(String(describing: T.self)).")
            return result
        } catch {
            Logger.ai.fault("JSON Decoding Error: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - OpenAI Response Structure

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Please add your OpenAI API Key in Settings."
        case .invalidResponse: return "The AI returned an invalid response."
        case .apiError(let code, let msg): return "AI Error (\(code)): \(msg)"
        }
    }
}
