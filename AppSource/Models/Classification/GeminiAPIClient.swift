//
//  GeminiAPIClient.swift
//  Settled
//
//  Created by Claude on 2025-01-08.
//  Simple Gemini API client for batch classification
//

import Foundation

/// Simple client for Gemini API calls
class GeminiAPIClient {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-1.5-flash-latest") {
        self.apiKey = apiKey
        self.model = model
    }

    /// Call Gemini API with a classification prompt
    func classify(prompt: String) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

        guard let url = URL(string: endpoint) else {
            throw GeminiAPIError.invalidURL
        }

        // Build request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,  // Low temperature for consistent classification
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30 // 30 second timeout

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Gemini API error (status \(httpResponse.statusCode)): \(errorMessage)")

            if httpResponse.statusCode == 429 {
                throw GeminiAPIError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 {
                throw GeminiAPIError.unauthorized
            } else {
                throw GeminiAPIError.httpError(httpResponse.statusCode, errorMessage)
            }
        }

        // Parse response
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiAPIError.invalidResponse
        }

        // Extract text from response
        guard let candidates = jsonResponse["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiAPIError.invalidResponse
        }

        return text
    }
}

/// Gemini API errors
enum GeminiAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case unauthorized
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini API URL"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .rateLimitExceeded:
            return "Gemini API rate limit exceeded"
        case .unauthorized:
            return "Gemini API unauthorized - check API key"
        case .httpError(let code, let message):
            return "Gemini API HTTP error \(code): \(message)"
        }
    }
}
