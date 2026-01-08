//
//  GeminiOnlyClassifier.swift
//  Settled
//
//  Created by Claude on 2025-01-08.
//  Gemini-first classification strategy for maximum accuracy
//

import Foundation

/// Simplified receipt classifier using only Gemini LLM in batch mode
/// Processes entire receipt in single API call for better accuracy and lower cost
class GeminiOnlyClassifier: ReceiptClassificationService {
    private let geminiAPI: GeminiAPIClient
    private let validator: ReceiptValidator

    init(apiKey: String) {
        self.geminiAPI = GeminiAPIClient(apiKey: apiKey)
        self.validator = ReceiptValidator(config: .geminiFirst)
    }

    // MARK: - Main Classification Interface

    func classify(_ items: [ReceiptItem], context: ReceiptContext) async -> ClassifiedReceipt {
        print("🤖 Starting Gemini-Only Classification")
        print("   Receipt type: \(context.receiptType.rawValue)")
        print("   Total items: \(items.count)")
        print("   Merchant: \(context.merchantName ?? "Unknown")")

        do {
            // 1. Build batch prompt with all items
            let prompt = buildBatchClassificationPrompt(items, context: context)
            print("📝 Built prompt: \(prompt.count) characters")

            // 2. Call Gemini API
            print("🌐 Calling Gemini API...")
            let startTime = Date()
            let response = try await geminiAPI.classify(prompt: prompt)
            let latency = Date().timeIntervalSince(startTime)
            print("✅ Gemini responded in \(String(format: "%.2f", latency))s")

            // 3. Parse JSON response
            print("🔍 Parsing classifications...")
            let classifications = try parseGeminiResponse(response)
            print("✅ Parsed \(classifications.count) classifications")

            // 4. Build classified receipt
            print("📦 Building classified receipt...")
            let receipt = buildClassifiedReceipt(items: items, classifications: classifications, context: context)

            // 5. Validate
            print("✔️  Validating receipt...")
            let validated = validator.validate(receipt, context: context)

            print("🎉 Classification complete!")
            print("   Food items: \(validated.foodItems.count)")
            print("   Tax: \(validated.tax?.price ?? 0)")
            print("   Tip: \(validated.tip?.price ?? 0)")
            print("   Total: \(validated.total?.price ?? 0)")
            print("   Overall confidence: \(String(format: "%.1f%%", validated.totalConfidence * 100))")

            return validated

        } catch {
            print("❌ Gemini classification failed: \(error)")
            print("⚠️  Falling back to basic classification")

            // Fallback: Basic keyword-based classification
            return fallbackClassification(items: items, context: context)
        }
    }

    // MARK: - Prompt Building (US-001)

    /// Builds comprehensive batch classification prompt for Gemini
    private func buildBatchClassificationPrompt(_ items: [ReceiptItem], context: ReceiptContext) -> String {
        // Build merchant context section
        let merchantInfo = context.merchantName ?? "Unknown merchant"
        let receiptTypeInfo = context.receiptType.rawValue.lowercased()

        // Format all items with position numbers
        let itemsSection = items.enumerated().map { index, item in
            "\(index + 1). \"\(item.name)\" - $\(String(format: "%.2f", item.price))"
        }.joined(separator: "\n")

        // Build complete prompt
        return """
        You are an expert receipt classification system. Your task is to classify every item in this receipt with high accuracy.

        RECEIPT CONTEXT:
        - Merchant: \(merchantInfo)
        - Type: \(receiptTypeInfo) receipt
        - Total Items: \(items.count)
        \(context.totalAmount.map { "- Expected Total: $\(String(format: "%.2f", $0))" } ?? "")

        ITEMS TO CLASSIFY:
        \(itemsSection)

        CLASSIFICATION CATEGORIES:
        - FOOD: Food or beverage items (dishes, drinks, desserts, etc.)
        - TAX: Sales tax or VAT
        - TIP: Gratuity or tip (manually added by customer)
        - GRATUITY: Auto-gratuity or service charge (e.g., "Large Party 20%")
        - SUBTOTAL: Subtotal before tax/tip
        - TOTAL: Final total amount
        - DISCOUNT: Discounts, coupons, or promotional reductions
        - SERVICE_CHARGE: Delivery fees, service charges, convenience fees
        - UNKNOWN: Cannot determine category

        CLASSIFICATION RULES:
        1. Analyze the item name and context carefully
        2. Look for quantity prefixes (e.g., "1", "2") to identify food items
        3. Distinguish between manual tips and auto-gratuity (look for percentages in name)
        4. Consider the receipt type when classifying (restaurant vs grocery vs retail)
        5. Use item position as a hint (totals usually at bottom)
        6. For ambiguous items, use surrounding context

        SPECIAL CASES TO WATCH FOR:
        - "Large Party (20.00%)" or similar → GRATUITY (not FOOD, even though it has a percentage)
        - "Service" or "Delivery" → SERVICE_CHARGE (not FOOD)
        - Items with quantity prefixes like "1 Pad Thai" → FOOD
        - Last line item is usually TOTAL
        - "Subtotal" or "Sub Total" → SUBTOTAL (not FOOD)

        OUTPUT FORMAT:
        Return ONLY a valid JSON object with this exact structure (no markdown, no explanation):
        {
          "classifications": [
            {
              "itemNumber": 1,
              "category": "FOOD",
              "confidence": 0.95,
              "reasoning": "Thai soup dish with quantity prefix"
            }
          ]
        }

        IMPORTANT:
        - Provide classification for ALL \(items.count) items
        - Confidence must be between 0.0 and 1.0
        - Be highly confident (>0.90) when certain
        - Use medium confidence (0.70-0.90) when somewhat certain
        - Use low confidence (<0.70) only when truly ambiguous
        - Provide clear reasoning for each classification

        Classify all items now:
        """
    }

    // MARK: - Response Parsing (US-002)

    /// Parses Gemini's JSON response into item classifications
    private func parseGeminiResponse(_ response: String) throws -> [ItemClassification] {
        print("🔍 Raw Gemini response length: \(response.count) characters")

        // Clean response - remove markdown code blocks if present
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json and ``` markers if present
        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedResponse.hasPrefix("```") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```", with: "")
        }
        if cleanedResponse.hasSuffix("```") {
            cleanedResponse = String(cleanedResponse.dropLast(3))
        }
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔍 Cleaned response: \(cleanedResponse.prefix(200))...")

        // Parse JSON
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw ClassificationError.invalidResponse("Could not convert response to UTF-8 data")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let parsed = try decoder.decode(GeminiClassificationResponse.self, from: jsonData)
            print("✅ Successfully parsed \(parsed.classifications.count) classifications")

            // Validate classifications
            guard !parsed.classifications.isEmpty else {
                throw ClassificationError.invalidResponse("No classifications in response")
            }

            return parsed.classifications

        } catch {
            print("❌ JSON parsing failed: \(error)")
            print("📄 Response was: \(cleanedResponse)")
            throw ClassificationError.invalidResponse("JSON parsing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Receipt Building (US-004)

    /// Builds ClassifiedReceipt from items and classifications
    private func buildClassifiedReceipt(
        items: [ReceiptItem],
        classifications: [ItemClassification],
        context: ReceiptContext
    ) -> ClassifiedReceipt {

        // Create lookup dictionary for fast classification access
        var classificationMap: [Int: ItemClassification] = [:]
        for classification in classifications {
            classificationMap[classification.itemNumber] = classification
        }

        // Classify each item
        var classifiedItems: [ClassifiedReceiptItem] = []
        var foodItems: [ClassifiedReceiptItem] = []
        var tax: ClassifiedReceiptItem? = nil
        var tip: ClassifiedReceiptItem? = nil
        var subtotal: ClassifiedReceiptItem? = nil
        var total: ClassifiedReceiptItem? = nil
        var discounts: [ClassifiedReceiptItem] = []
        var serviceCharges: [ClassifiedReceiptItem] = []

        for (index, item) in items.enumerated() {
            let itemNumber = index + 1

            guard let classification = classificationMap[itemNumber] else {
                print("⚠️  No classification for item \(itemNumber), defaulting to UNKNOWN")
                let unknown = ClassifiedReceiptItem(
                    from: item,
                    position: index,
                    category: .unknown,
                    confidence: 0.3,
                    method: .llm
                )
                classifiedItems.append(unknown)
                continue
            }

            // Parse category
            let category = ItemCategory.from(string: classification.category)

            // Create classified item
            let classifiedItem = ClassifiedReceiptItem(
                from: item,
                position: index,
                category: category,
                confidence: classification.confidence,
                method: .llm
            )

            classifiedItems.append(classifiedItem)

            // Sort into appropriate category
            switch category {
            case .food:
                foodItems.append(classifiedItem)
            case .tax:
                tax = classifiedItem
            case .tip:
                tip = classifiedItem
            case .subtotal:
                subtotal = classifiedItem
            case .total:
                total = classifiedItem
            case .discount:
                discounts.append(classifiedItem)
            case .serviceCharge, .gratuity:
                serviceCharges.append(classifiedItem)
            case .deliveryFee:
                serviceCharges.append(classifiedItem)
            case .unknown:
                break
            }
        }

        // Calculate overall confidence
        let totalConfidence = classifications.reduce(0.0) { $0 + $1.confidence }
        let overallConfidence = totalConfidence / Double(classifications.count)

        // Determine validation status
        let validationStatus: ValidationStatus
        if overallConfidence >= 0.90 && tax != nil && total != nil {
            validationStatus = .valid
        } else if overallConfidence >= 0.70 {
            validationStatus = .warning
        } else {
            validationStatus = .needsReview
        }

        // Collect unknown items
        let unknownItems = classifiedItems.filter { $0.category == .unknown }

        return ClassifiedReceipt(
            foodItems: foodItems,
            tax: tax,
            tip: tip,
            gratuity: serviceCharges.first(where: { $0.category == .gratuity }),
            subtotal: subtotal,
            total: total,
            discounts: discounts,
            otherCharges: serviceCharges.filter { $0.category != .gratuity },
            unknownItems: unknownItems,
            totalConfidence: overallConfidence,
            validationStatus: validationStatus,
            validationIssues: [] // Will be filled by validator
        )
    }

    // MARK: - Fallback Classification

    /// Simple keyword-based fallback when Gemini fails
    private func fallbackClassification(items: [ReceiptItem], context: ReceiptContext) -> ClassifiedReceipt {
        print("⚠️  Using fallback classification")

        var classifiedItems: [ClassifiedReceiptItem] = []
        var foodItems: [ClassifiedReceiptItem] = []
        var tax: ClassifiedReceiptItem? = nil
        var tip: ClassifiedReceiptItem? = nil
        var subtotal: ClassifiedReceiptItem? = nil
        var total: ClassifiedReceiptItem? = nil

        for (index, item) in items.enumerated() {
            let name = item.name.lowercased()

            let category: ItemCategory
            let confidence: Double

            if name.contains("tax") {
                category = .tax
                confidence = 0.9
            } else if name.contains("tip") {
                category = .tip
                confidence = 0.9
            } else if name.contains("subtotal") || name.contains("sub total") {
                category = .subtotal
                confidence = 0.9
            } else if name.contains("total") {
                category = .total
                confidence = 0.9
            } else if name.starts(with: "1 ") || name.starts(with: "2 ") || name.starts(with: "3 ") {
                category = .food
                confidence = 0.7
            } else {
                category = .unknown
                confidence = 0.3
            }

            let classified = ClassifiedReceiptItem(
                from: item,
                position: index,
                category: category,
                confidence: confidence,
                method: .heuristic
            )

            classifiedItems.append(classified)

            switch category {
            case .food: foodItems.append(classified)
            case .tax: tax = classified
            case .tip: tip = classified
            case .subtotal: subtotal = classified
            case .total: total = classified
            default: break
            }
        }

        let unknownItems = classifiedItems.filter { $0.category == .unknown }

        return ClassifiedReceipt(
            foodItems: foodItems,
            tax: tax,
            tip: tip,
            gratuity: nil,
            subtotal: subtotal,
            total: total,
            discounts: [],
            otherCharges: [],
            unknownItems: unknownItems,
            totalConfidence: 0.5,
            validationStatus: .needsReview,
            validationIssues: [ValidationIssue(
                type: .missingTotal,
                message: "Classification failed, used fallback",
                severity: .warning,
                affectedItemIds: []
            )]
        )
    }
}

// MARK: - Supporting Models (US-002)

/// Response structure from Gemini API
struct GeminiClassificationResponse: Codable {
    let classifications: [ItemClassification]
}

/// Individual item classification from Gemini
struct ItemClassification: Codable {
    let itemNumber: Int
    let category: String
    let confidence: Double
    let reasoning: String
}

/// Classification errors
enum ClassificationError: Error, LocalizedError {
    case invalidResponse(String)
    case apiError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        case .apiError(let details):
            return "API error: \(details)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - ItemCategory Helper Extension

extension ItemCategory {
    /// Convert string to ItemCategory
    static func from(string: String) -> ItemCategory {
        switch string.uppercased() {
        case "FOOD": return .food
        case "TAX": return .tax
        case "TIP": return .tip
        case "GRATUITY": return .gratuity
        case "SUBTOTAL": return .subtotal
        case "TOTAL": return .total
        case "DISCOUNT": return .discount
        case "SERVICE_CHARGE": return .serviceCharge
        default: return .unknown
        }
    }
}
