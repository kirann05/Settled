//
//  GeminiClassificationStrategy.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

/// Gemini LLM-based classification strategy
/// Fallback for low-confidence heuristic classifications
class GeminiClassificationStrategy: ClassificationStrategy {
    private let config: ClassificationConfig
    private let apiKeyProvider: APIKeyProvider
    private let rateLimiter: RateLimiter

    init(config: ClassificationConfig = .default, apiKeyProvider: APIKeyProvider = KeychainAPIKeyProvider()) {
        self.config = config
        self.apiKeyProvider = apiKeyProvider
        self.rateLimiter = RateLimiter(maxCallsPerReceipt: config.maxGeminiCallsPerReceipt)
    }

    func canClassify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) -> Bool {
        // Only use Gemini if:
        // 1. Gemini is enabled in config
        // 2. Rate limiter allows more calls
        // 3. API key is available
        guard config.enableGeminiClassification else { return false }
        guard rateLimiter.canMakeCall() else { return false }
        guard apiKeyProvider.hasAPIKey() else { return false }

        return true
    }

    func classify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) async -> ClassificationResult {
        print("  🤖 Gemini LLM Classification: '\(item.name)'")

        do {
            // Increment rate limiter
            rateLimiter.recordCall()

            // Get API key
            guard let apiKey = try apiKeyProvider.getAPIKey() else {
                return ClassificationResult(
                    category: .unknown,
                    confidence: 0.0,
                    method: .llm,
                    reasoning: "API key not configured"
                )
            }

            // Build prompt
            let prompt = buildClassificationPrompt(item: item, position: position, context: context)

            // Call Gemini API
            let response = try await callGeminiAPI(prompt: prompt, apiKey: apiKey)

            // Parse response
            let result = try parseGeminiResponse(response)

            print("    ✅ Gemini classified as: \(result.category) (confidence: \(result.confidence))")
            return result

        } catch {
            print("    ❌ Gemini API error: \(error.localizedDescription)")
            return ClassificationResult(
                category: .unknown,
                confidence: 0.0,
                method: .llm,
                reasoning: "LLM classification failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Prompt Engineering

    private func buildClassificationPrompt(item: ReceiptItem, position: Int, context: ReceiptContext) -> String {
        """
        You are a receipt item classifier. Classify the following receipt line item into one of these categories:

        Categories:
        - FOOD: Food and beverage items ordered by customers
        - TAX: Sales tax, VAT, GST, HST, or other government taxes
        - TIP: Optional gratuity added by customer
        - GRATUITY: Mandatory auto-added gratuity (e.g., "Large Party 20%")
        - SUBTOTAL: Sum of all food items before tax/tip
        - TOTAL: Final amount to be paid (subtotal + tax + tip + fees - discounts)
        - DISCOUNT: Coupons, promotions, price reductions (usually negative or "off")
        - SERVICE_CHARGE: Mandatory service fees (not gratuity)
        - DELIVERY_FEE: Delivery or shipping charges
        - UNKNOWN: Cannot determine category with confidence

        Receipt Context:
        - Receipt Type: \(context.receiptType.rawValue)
        - Total Items: \(context.itemCount)
        - Expected Total: \(context.totalAmount.map { String(format: "$%.2f", $0) } ?? "unknown")
        - Expected Subtotal: \(context.subtotalAmount.map { String(format: "$%.2f", $0) } ?? "unknown")
        \(context.merchantName.map { "- Merchant: \($0)" } ?? "")

        Item to Classify:
        - Name: "\(item.name)"
        - Price: $\(String(format: "%.2f", item.price))
        - Position: \(context.itemCount > 0 ? "\(position + 1) of \(context.itemCount)" : "unknown")

        Classification Rules:
        1. TAX vs TIP: Tax is government-mandated (keywords: tax, vat, gst, hst), Tip is customer gratuity (keywords: tip, pourboire, propina)
        2. TIP vs GRATUITY: Tip is optional (usually hand-written), Gratuity is auto-added mandatory (keywords: auto grat, large party, service charge with %)
        3. SUBTOTAL vs TOTAL: Subtotal excludes tax/tip, Total includes everything
        4. SERVICE_CHARGE vs GRATUITY: Service charge is non-tip fee (processing, convenience), Gratuity is tip
        5. Position matters: TOTAL usually last, TAX/TIP near end, SUBTOTAL before tax/tip, FOOD items in middle

        Respond ONLY with valid JSON (no markdown, no explanation):
        {
          "category": "<CATEGORY>",
          "confidence": <0.0-1.0>,
          "reasoning": "<brief explanation>"
        }
        """
    }

    // MARK: - Gemini API Integration

    private func callGeminiAPI(prompt: String, apiKey: String) async throws -> String {
        // Gemini API endpoint
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(apiKey)"

        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
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
                "temperature": 0.0,  // Deterministic classification
                "topK": 1,
                "topP": 1,
                "maxOutputTokens": 200,  // JSON response is small
                "responseMimeType": "application/json"  // Force JSON response
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
        request.timeoutInterval = 10.0  // 10 second timeout

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("    ⚠️ Gemini API error (\(httpResponse.statusCode)): \(errorBody)")
            throw GeminiError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parseError
        }

        return text
    }

    private func parseGeminiResponse(_ response: String) throws -> ClassificationResult {
        // Parse JSON response
        guard let jsonData = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let categoryString = json["category"] as? String,
              let confidence = json["confidence"] as? Double,
              let reasoning = json["reasoning"] as? String else {
            throw GeminiError.parseError
        }

        // Parse category
        guard let category = ItemCategory(rawValue: categoryString) else {
            throw GeminiError.invalidCategory(categoryString)
        }

        return ClassificationResult(
            category: category,
            confidence: confidence,
            method: .llm,
            reasoning: "Gemini: \(reasoning)"
        )
    }
}

// MARK: - API Key Provider

protocol APIKeyProvider {
    func hasAPIKey() -> Bool
    func getAPIKey() throws -> String?
    func setAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

/// Keychain-based secure API key storage
class KeychainAPIKeyProvider: APIKeyProvider {
    private let service = "com.settled.gemini"
    private let account = "api_key"

    func hasAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return apiKey
    }

    func setAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete existing key if present
        try? deleteAPIKey()

        // Add new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - Rate Limiter

/// Prevents excessive Gemini API calls per receipt
class RateLimiter {
    private let maxCalls: Int
    private var callCount: Int = 0

    init(maxCallsPerReceipt: Int) {
        self.maxCalls = maxCallsPerReceipt
    }

    func canMakeCall() -> Bool {
        return callCount < maxCalls
    }

    func recordCall() {
        callCount += 1
    }

    func reset() {
        callCount = 0
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case parseError
    case invalidCategory(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini API URL"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .httpError(let code, let message):
            return "Gemini API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse Gemini response"
        case .invalidCategory(let category):
            return "Invalid category returned: \(category)"
        }
    }
}

enum KeychainError: LocalizedError {
    case invalidData
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid keychain data"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}
