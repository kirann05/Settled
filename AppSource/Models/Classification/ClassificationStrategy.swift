//
//  ClassificationStrategy.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

// MARK: - Classification Strategy Protocol

/// Strategy for classifying a receipt item
protocol ClassificationStrategy {
    /// Check if this strategy can classify the given item
    /// - Parameters:
    ///   - item: Receipt item to check
    ///   - context: Receipt context
    /// - Returns: True if this strategy can attempt classification
    func canClassify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) -> Bool

    /// Classify the item
    /// - Parameters:
    ///   - item: Receipt item to classify
    ///   - position: Position in receipt (0-based)
    ///   - context: Receipt context
    /// - Returns: Classification result
    func classify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) async -> ClassificationResult
}

// MARK: - Classification Strategy Chain

/// Chain of responsibility for classification strategies
class ClassificationStrategyChain {
    private let strategies: [ClassificationStrategy]
    private let config: ClassificationConfig

    init(strategies: [ClassificationStrategy], config: ClassificationConfig = .default) {
        self.strategies = strategies
        self.config = config
    }

    /// Classify an item using the strategy chain
    /// - Parameters:
    ///   - item: Receipt item to classify
    ///   - position: Position in receipt
    ///   - context: Receipt context
    /// - Returns: Best classification result from strategies
    func classify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) async -> ClassificationResult {
        print("🔗 Strategy Chain: Classifying '\(item.name)' at position \(position)")

        var bestResult: ClassificationResult?

        for (index, strategy) in strategies.enumerated() {
            let strategyName = String(describing: type(of: strategy))

            // Check if strategy can classify
            guard strategy.canClassify(item, at: position, context: context) else {
                print("  ⏭️  Strategy \(index + 1)/\(strategies.count) (\(strategyName)): Cannot classify, skipping")
                continue
            }

            // Attempt classification
            let result = await strategy.classify(item, at: position, context: context)

            print("  📊 Strategy \(index + 1)/\(strategies.count) (\(strategyName)): " +
                  "\(result.category.rawValue) (confidence: \(String(format: "%.2f", result.confidence)))")

            // Track best result so far
            if result.confidence > (bestResult?.confidence ?? 0) {
                bestResult = result
            }

            // If high confidence (>= highConfidenceThreshold), stop here
            if result.confidence >= config.highConfidenceThreshold {
                print("  ✅ High confidence result (\(String(format: "%.2f", result.confidence)) >= \(String(format: "%.2f", config.highConfidenceThreshold))), stopping chain")
                return result
            }

            // If medium confidence and not last strategy, continue to next strategy
            if result.confidence >= config.mediumConfidenceThreshold && index < strategies.count - 1 {
                print("  ⚠️  Medium confidence (\(String(format: "%.2f", result.confidence)) >= \(String(format: "%.2f", config.mediumConfidenceThreshold))), trying next strategy")
                continue
            }

            // If this is the last strategy, accept whatever result we got (even if low confidence)
            if index == strategies.count - 1 && result.confidence > 0 {
                print("  ✓  Last strategy result, accepting \(strategyName)")
                return result
            }

            // If below medium confidence threshold and not last strategy, continue
            if result.confidence < config.mediumConfidenceThreshold && index < strategies.count - 1 {
                print("  ⏭️  Low confidence (\(String(format: "%.2f", result.confidence)) < \(String(format: "%.2f", config.mediumConfidenceThreshold))), trying next strategy")
                continue
            }

            // Fallback: accept this result
            if result.confidence > 0 {
                print("  ✓  Accepting result from \(strategyName)")
                return result
            }
        }

        // Return best result if we have one
        if let bestResult = bestResult, bestResult.confidence > 0 {
            print("  ✅ Returning best result: \(bestResult.category.rawValue) (confidence: \(String(format: "%.2f", bestResult.confidence)))")
            return bestResult
        }

        // No strategy could classify with confidence
        print("  ❌ No strategy could classify, returning UNKNOWN")
        return ClassificationResult(
            category: .unknown,
            confidence: 0.0,
            method: .heuristic,
            reasoning: "No strategy produced confident classification"
        )
    }

    /// Classify all items in a receipt
    /// - Parameters:
    ///   - items: List of receipt items
    ///   - context: Receipt context
    /// - Returns: Array of classification results
    func classifyAll(_ items: [ReceiptItem], context: ReceiptContext) async -> [ClassificationResult] {
        print("\n🔗 Classifying \(items.count) items with strategy chain")

        var results: [ClassificationResult] = []

        for (position, item) in items.enumerated() {
            let result = await classify(item, at: position, context: context)
            results.append(result)
        }

        print("✅ Classification complete: \(results.filter { $0.isHighConfidence }.count)/\(results.count) high confidence\n")

        return results
    }
}

// MARK: - Helper Extensions

extension ReceiptItem {
    /// Whether this item's name is very short (likely abbreviation or summary)
    var hasShortName: Bool {
        return name.count <= 3
    }

    /// Whether this item's name is all uppercase (likely POS code)
    var isAllUppercase: Bool {
        return name == name.uppercased() && name.rangeOfCharacter(from: .lowercaseLetters) == nil
    }

    /// Whether this item's price is negative (discount/refund)
    var isNegativePrice: Bool {
        return price < 0
    }

    /// Whether this item's price is very small (< $1)
    var isSmallPrice: Bool {
        return price > 0 && price < 1.0
    }

    /// Whether this item's name contains a percentage
    var containsPercentage: Bool {
        return name.contains("%") || name.range(of: "\\d+\\.?\\d*\\s*%", options: .regularExpression) != nil
    }

    /// Extract percentage value if present
    func extractPercentage() -> Double? {
        guard let regex = try? NSRegularExpression(pattern: "(\\d+\\.?\\d*)\\s*%", options: []) else {
            return nil
        }

        let range = NSRange(name.startIndex..., in: name)
        guard let match = regex.firstMatch(in: name, range: range),
              let percentRange = Range(match.range(at: 1), in: name) else {
            return nil
        }

        let percentString = String(name[percentRange])
        return Double(percentString)
    }

    /// Whether this item's name starts with a quantity (e.g., "2 Burgers")
    var startsWithQuantity: Bool {
        return name.range(of: "^\\d+\\s+", options: .regularExpression) != nil ||
               name.range(of: "^\\d+x\\s+", options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Extract quantity if present
    func extractQuantity() -> Int? {
        // Pattern: "2 Burgers" or "3x Fries"
        guard let regex = try? NSRegularExpression(pattern: "^(\\d+)(?:x)?\\s+", options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(name.startIndex..., in: name)
        guard let match = regex.firstMatch(in: name, range: range),
              let qtyRange = Range(match.range(at: 1), in: name) else {
            return nil
        }

        let qtyString = String(name[qtyRange])
        return Int(qtyString)
    }
}

extension ReceiptContext {
    /// Whether this receipt is likely from a restaurant
    var isRestaurant: Bool {
        return receiptType == .restaurant
    }

    /// Whether this receipt is likely from a grocery store
    var isGrocery: Bool {
        return receiptType == .grocery
    }

    /// Whether this receipt type typically has tips
    var expectsTip: Bool {
        return receiptType.expectsTip
    }

    /// Whether this receipt type typically has service charges
    var expectsServiceCharge: Bool {
        return receiptType.expectsServiceCharge
    }

    /// Get expected total amount (if known)
    var expectedTotal: Double? {
        return totalAmount
    }

    /// Get expected subtotal amount (if known)
    var expectedSubtotal: Double? {
        return subtotalAmount
    }
}
