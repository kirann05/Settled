//
//  ReceiptClassificationService.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

// MARK: - Receipt Type

/// Type of receipt (helps with classification heuristics)
enum ReceiptType: String, Codable {
    case restaurant = "RESTAURANT"
    case grocery = "GROCERY"
    case retail = "RETAIL"
    case delivery = "DELIVERY"
    case unknown = "UNKNOWN"

    /// Typical tax rate range for this receipt type
    var typicalTaxRange: ClosedRange<Double> {
        switch self {
        case .restaurant: return 0.05...0.12    // 5-12%
        case .grocery: return 0.00...0.10       // 0-10% (some items tax-exempt)
        case .retail: return 0.05...0.15        // 5-15%
        case .delivery: return 0.05...0.12      // 5-12%
        case .unknown: return 0.00...0.20       // Wide range
        }
    }

    /// Typical tip range for this receipt type
    var typicalTipRange: ClosedRange<Double> {
        switch self {
        case .restaurant: return 0.15...0.25    // 15-25%
        case .delivery: return 0.10...0.20      // 10-20%
        case .grocery, .retail, .unknown: return 0.00...0.30  // Variable
        }
    }

    /// Whether this receipt type typically has tips
    var expectsTip: Bool {
        switch self {
        case .restaurant, .delivery: return true
        case .grocery, .retail, .unknown: return false
        }
    }

    /// Whether this receipt type typically has service charges
    var expectsServiceCharge: Bool {
        switch self {
        case .restaurant: return true   // Auto-gratuity for large parties
        case .delivery: return true     // Delivery/service fees
        case .grocery, .retail, .unknown: return false
        }
    }
}

// MARK: - Receipt Context

/// Context information about a receipt to aid classification
struct ReceiptContext: Codable {
    let totalAmount: Double?           // Extracted total for validation
    let subtotalAmount: Double?        // Extracted subtotal
    let itemCount: Int                 // Number of line items detected
    let receiptType: ReceiptType       // Type of receipt
    let detectedLanguage: String?      // ISO language code (e.g., "en", "fr", "es")
    let merchantName: String?          // Merchant/store name if detected
    let date: Date?                    // Receipt date if detected

    init(
        totalAmount: Double? = nil,
        subtotalAmount: Double? = nil,
        itemCount: Int = 0,
        receiptType: ReceiptType = .unknown,
        detectedLanguage: String? = nil,
        merchantName: String? = nil,
        date: Date? = nil
    ) {
        self.totalAmount = totalAmount
        self.subtotalAmount = subtotalAmount
        self.itemCount = itemCount
        self.receiptType = receiptType
        self.detectedLanguage = detectedLanguage
        self.merchantName = merchantName
        self.date = date
    }

    /// Create context from OCR result
    static func from(ocrResult: OCRResult) -> ReceiptContext {
        let itemCount = ocrResult.parsedItems.count

        // Try to detect receipt type from items
        let receiptType = detectReceiptType(from: ocrResult.parsedItems)

        return ReceiptContext(
            totalAmount: ocrResult.identifiedTotal,
            subtotalAmount: nil,  // Not currently extracted
            itemCount: itemCount,
            receiptType: receiptType,
            detectedLanguage: "en",  // Default to English for now
            merchantName: nil,       // Not currently extracted
            date: nil                // Not currently extracted
        )
    }

    /// Simple receipt type detection heuristic
    private static func detectReceiptType(from items: [ReceiptItem]) -> ReceiptType {
        let itemNames = items.map { $0.name.lowercased() }

        // Restaurant keywords
        let restaurantKeywords = ["burger", "pizza", "fries", "drink", "soda", "entree", "appetizer", "dessert", "meal", "sandwich"]
        let restaurantMatches = itemNames.filter { name in
            restaurantKeywords.contains(where: { name.contains($0) })
        }.count

        // Grocery keywords
        let groceryKeywords = ["milk", "bread", "eggs", "produce", "meat", "organic", "fresh"]
        let groceryMatches = itemNames.filter { name in
            groceryKeywords.contains(where: { name.contains($0) })
        }.count

        // Delivery keywords
        let deliveryKeywords = ["delivery", "shipping", "postage"]
        let deliveryMatches = itemNames.filter { name in
            deliveryKeywords.contains(where: { name.contains($0) })
        }.count

        // Determine type based on matches
        if deliveryMatches > 0 {
            return .delivery
        } else if restaurantMatches >= 2 {
            return .restaurant
        } else if groceryMatches >= 2 {
            return .grocery
        } else if items.count > 10 {
            return .grocery  // Many items likely grocery
        }

        return .unknown
    }

    /// Expected tax rate range based on receipt type
    var expectedTaxRange: ClosedRange<Double> {
        return receiptType.typicalTaxRange
    }

    /// Expected tip rate range based on receipt type
    var expectedTipRange: ClosedRange<Double> {
        return receiptType.typicalTipRange
    }
}

// MARK: - Classification Service Protocol

/// Service for classifying receipt items
protocol ReceiptClassificationService {
    /// Classify a list of receipt items
    /// - Parameters:
    ///   - items: Raw receipt items to classify
    ///   - context: Receipt context for classification hints
    /// - Returns: Classified receipt with validation
    func classify(_ items: [ReceiptItem], context: ReceiptContext) async -> ClassifiedReceipt
}

// MARK: - Classification Configuration

/// Configuration for classification behavior
struct ClassificationConfig {
    // Feature flags
    let enableGeminiClassification: Bool
    let enableHeuristicClassification: Bool
    let enableValidation: Bool

    // Confidence thresholds
    let highConfidenceThreshold: Double       // >= this = high confidence
    let mediumConfidenceThreshold: Double     // >= this = medium confidence
    let geminiConfidenceThreshold: Double     // < this = use Gemini

    // Cost controls
    let maxGeminiCallsPerReceipt: Int
    let geminiRateLimit: Int                  // Calls per minute

    // Validation tolerances
    let sumValidationTolerance: Double        // Percent tolerance for sum validation
    let taxRateMin: Double
    let taxRateMax: Double
    let tipRateMin: Double
    let tipRateMax: Double

    static let `default` = ClassificationConfig(
        enableGeminiClassification: true,
        enableHeuristicClassification: true,
        enableValidation: true,
        highConfidenceThreshold: 0.8,
        mediumConfidenceThreshold: 0.6,
        geminiConfidenceThreshold: 0.7,
        maxGeminiCallsPerReceipt: 5,
        geminiRateLimit: 60,
        sumValidationTolerance: 0.01,  // 1%
        taxRateMin: 0.05,
        taxRateMax: 0.15,
        tipRateMin: 0.10,
        tipRateMax: 0.30
    )

    static let conservative = ClassificationConfig(
        enableGeminiClassification: false,  // Disable Gemini to save costs
        enableHeuristicClassification: true,
        enableValidation: true,
        highConfidenceThreshold: 0.9,
        mediumConfidenceThreshold: 0.7,
        geminiConfidenceThreshold: 0.8,
        maxGeminiCallsPerReceipt: 3,
        geminiRateLimit: 30,
        sumValidationTolerance: 0.02,  // 2%
        taxRateMin: 0.05,
        taxRateMax: 0.15,
        tipRateMin: 0.10,
        tipRateMax: 0.30
    )

    static let aggressive = ClassificationConfig(
        enableGeminiClassification: true,
        enableHeuristicClassification: true,
        enableValidation: true,
        highConfidenceThreshold: 0.7,
        mediumConfidenceThreshold: 0.5,
        geminiConfidenceThreshold: 0.6,  // Use Gemini more often
        maxGeminiCallsPerReceipt: 10,
        geminiRateLimit: 100,
        sumValidationTolerance: 0.03,  // 3%
        taxRateMin: 0.00,
        taxRateMax: 0.20,
        tipRateMin: 0.05,
        tipRateMax: 0.40
    )

    static let geminiFirst = ClassificationConfig(
        enableGeminiClassification: true,
        enableHeuristicClassification: true,
        enableValidation: true,
        highConfidenceThreshold: 0.99,    // Require 99% confidence from geometric/pattern strategies
        mediumConfidenceThreshold: 0.95,  // Even medium confidence requires 95%
        geminiConfidenceThreshold: 0.99,  // Fall through to Gemini for anything < 99%
        maxGeminiCallsPerReceipt: 50,     // Allow many Gemini calls
        geminiRateLimit: 100,
        sumValidationTolerance: 0.03,     // 3%
        taxRateMin: 0.00,
        taxRateMax: 0.20,
        tipRateMin: 0.05,
        tipRateMax: 0.40
    )
}

// MARK: - Classification Engine Selection

/// Classification engine type for A/B testing
enum ClassificationEngine: String, Codable {
    case legacy      // Multi-strategy chain (Geometric → Pattern → Price → Gemini)
    case geminiOnly  // New Gemini-only batch classifier

    /// Persisted engine selection (for A/B testing)
    static var current: ClassificationEngine {
        get {
            if let stored = UserDefaults.standard.string(forKey: "classificationEngine"),
               let engine = ClassificationEngine(rawValue: stored) {
                return engine
            }
            return .legacy  // Default to legacy during testing phase
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "classificationEngine")
            print("🔄 Classification engine changed to: \(newValue.rawValue)")
        }
    }
}

// MARK: - Classification Result

/// Result of classifying a single item
struct ClassificationResult {
    let category: ItemCategory
    let confidence: Double          // 0.0 - 1.0
    let method: ClassificationMethod
    let reasoning: String?          // Optional explanation (useful for debugging/LLM)

    init(category: ItemCategory, confidence: Double, method: ClassificationMethod, reasoning: String? = nil) {
        self.category = category
        self.confidence = confidence
        self.method = method
        self.reasoning = reasoning
    }

    /// Whether this classification is high confidence
    var isHighConfidence: Bool {
        return confidence >= 0.8
    }

    /// Whether this classification needs review
    var needsReview: Bool {
        return confidence < 0.7
    }
}
