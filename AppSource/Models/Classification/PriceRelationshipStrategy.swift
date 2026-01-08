//
//  PriceRelationshipStrategy.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

/// Mathematical relationship-based classification strategy
/// Uses price relationships, tax rates, and sum validation to classify items
class PriceRelationshipStrategy: ClassificationStrategy {
    private let config: ClassificationConfig

    init(config: ClassificationConfig = .default) {
        self.config = config
    }

    func canClassify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) -> Bool {
        // Can classify any item if we have subtotal or total for reference
        return context.subtotalAmount != nil || context.totalAmount != nil
    }

    func classify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) async -> ClassificationResult {
        print("  🔢 Price Relationship Analysis: '\(item.name)'")

        // Check relationships in order of reliability

        // 1. Tax rate validation (highest confidence)
        if let taxResult = classifyByTaxRate(item, context: context) {
            return taxResult
        }

        // 2. Tip rate validation
        if let tipResult = classifyByTipRate(item, context: context) {
            return tipResult
        }

        // 3. Total sum validation
        if let totalResult = classifyByTotalSum(item, context: context) {
            return totalResult
        }

        // 4. Subtotal sum validation
        if let subtotalResult = classifyBySubtotalSum(item, context: context) {
            return subtotalResult
        }

        // 5. Price magnitude relative to subtotal
        if let magnitudeResult = classifyByPriceMagnitude(item, context: context) {
            return magnitudeResult
        }

        // No clear relationship found
        return ClassificationResult(
            category: .unknown,
            confidence: 0.1,
            method: .heuristic,
            reasoning: "No clear price relationship detected"
        )
    }

    // MARK: - Tax Rate Validation

    /// Classify items by validating against expected tax rates
    private func classifyByTaxRate(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        guard let subtotal = context.subtotalAmount, subtotal > 0 else { return nil }

        let itemName = item.name.lowercased()

        // Only check items that might be tax
        guard itemName.contains("tax") || itemName.contains("vat") || itemName.contains("gst") || itemName.contains("hst") else {
            return nil
        }

        // Calculate implied tax rate
        let impliedTaxRate = (item.price / subtotal) * 100.0
        print("    💰 Implied tax rate: \(impliedTaxRate)%")

        // Get expected tax range for receipt type
        let expectedRange = context.receiptType.typicalTaxRange
        let expectedRangePercent = (expectedRange.lowerBound * 100)...(expectedRange.upperBound * 100)

        // Check if implied rate falls within expected range
        if expectedRangePercent.contains(impliedTaxRate) {
            let confidence = calculateTaxConfidence(
                impliedRate: impliedTaxRate,
                expectedRange: expectedRangePercent,
                itemName: itemName
            )

            return ClassificationResult(
                category: .tax,
                confidence: confidence,
                method: .heuristic,
                reasoning: "Tax rate (\(String(format: "%.1f", impliedTaxRate))%) matches expected range for \(context.receiptType.rawValue)"
            )
        }

        // Tax rate out of expected range - lower confidence but still likely tax
        if impliedTaxRate > 0 && impliedTaxRate < 20.0 {
            return ClassificationResult(
                category: .tax,
                confidence: 0.60,
                method: .heuristic,
                reasoning: "Tax rate (\(String(format: "%.1f", impliedTaxRate))%) outside expected range but plausible"
            )
        }

        return nil
    }

    private func calculateTaxConfidence(impliedRate: Double, expectedRange: ClosedRange<Double>, itemName: String) -> Double {
        let rangeCenter = (expectedRange.lowerBound + expectedRange.upperBound) / 2.0
        let deviation = abs(impliedRate - rangeCenter)
        let rangeWidth = expectedRange.upperBound - expectedRange.lowerBound

        // Base confidence on how close to center of expected range
        var confidence = max(0.5, 1.0 - (deviation / rangeWidth))

        // Boost confidence if name is explicit
        if itemName == "tax" || itemName == "sales tax" || itemName == "vat" {
            confidence = min(1.0, confidence + 0.15)
        }

        return confidence
    }

    // MARK: - Tip Rate Validation

    /// Classify items by validating against expected tip rates
    private func classifyByTipRate(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        guard let subtotal = context.subtotalAmount, subtotal > 0 else { return nil }

        let itemName = item.name.lowercased()

        // Only check items that might be tip or gratuity
        guard itemName.contains("tip") || itemName.contains("grat") || itemName.contains("service") else {
            return nil
        }

        // Calculate implied tip rate
        let impliedTipRate = (item.price / subtotal) * 100.0
        print("    💵 Implied tip rate: \(impliedTipRate)%")

        // Typical tip range: 10-30%
        let typicalTipRange = 10.0...30.0

        // Check if implied rate falls within typical range
        if typicalTipRange.contains(impliedTipRate) {
            let confidence = calculateTipConfidence(
                impliedRate: impliedTipRate,
                itemName: itemName
            )

            // Distinguish between tip and gratuity
            let category: ItemCategory = itemName.contains("grat") || itemName.contains("auto") || itemName.contains("party") ? .gratuity : .tip

            return ClassificationResult(
                category: category,
                confidence: confidence,
                method: .heuristic,
                reasoning: "Tip rate (\(String(format: "%.1f", impliedTipRate))%) in typical range (10-30%)"
            )
        }

        // Tip rate outside typical range but still plausible
        if impliedTipRate > 5.0 && impliedTipRate < 40.0 {
            let category: ItemCategory = itemName.contains("grat") ? .gratuity : .tip

            return ClassificationResult(
                category: category,
                confidence: 0.55,
                method: .heuristic,
                reasoning: "Tip rate (\(String(format: "%.1f", impliedTipRate))%) outside typical range but plausible"
            )
        }

        return nil
    }

    private func calculateTipConfidence(impliedRate: Double, itemName: String) -> Double {
        // Standard tip rates: 15%, 18%, 20%, 22%, 25%
        let standardRates = [15.0, 18.0, 20.0, 22.0, 25.0]

        // Find closest standard rate
        let closestRate = standardRates.min(by: { abs($0 - impliedRate) < abs($1 - impliedRate) }) ?? 20.0
        let deviation = abs(impliedRate - closestRate)

        // High confidence if very close to standard rate
        var confidence = max(0.6, 1.0 - (deviation / 10.0))

        // Boost confidence for explicit names
        if itemName == "tip" || itemName == "gratuity" {
            confidence = min(1.0, confidence + 0.10)
        }

        return confidence
    }

    // MARK: - Total Sum Validation

    /// Classify items by checking if they complete the total equation
    private func classifyByTotalSum(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        guard let expectedTotal = context.totalAmount else { return nil }

        let itemName = item.name.lowercased()

        // Only check items that might be total
        guard itemName.contains("total") && !itemName.contains("sub") else {
            return nil
        }

        // Check if item price matches expected total (within 1% tolerance)
        let percentDiff = abs((item.price - expectedTotal) / expectedTotal) * 100.0
        print("    📊 Total match: item=$\(item.price), expected=$\(expectedTotal), diff=\(percentDiff)%")

        if percentDiff < 1.0 {
            return ClassificationResult(
                category: .total,
                confidence: 0.95,
                method: .heuristic,
                reasoning: "Price matches expected total (within \(String(format: "%.1f", percentDiff))%)"
            )
        }

        // Close match but not exact
        if percentDiff < 5.0 {
            return ClassificationResult(
                category: .total,
                confidence: 0.75,
                method: .heuristic,
                reasoning: "Price close to expected total (within \(String(format: "%.1f", percentDiff))%)"
            )
        }

        return nil
    }

    // MARK: - Subtotal Sum Validation

    /// Classify items by checking if they're close to subtotal
    private func classifyBySubtotalSum(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        guard let expectedSubtotal = context.subtotalAmount else { return nil }

        let itemName = item.name.lowercased()

        // Only check items that might be subtotal
        guard itemName.contains("subtotal") || itemName.contains("sub total") || itemName.contains("sub-total") else {
            return nil
        }

        // Check if item price matches expected subtotal (within 2% tolerance)
        let percentDiff = abs((item.price - expectedSubtotal) / expectedSubtotal) * 100.0
        print("    📊 Subtotal match: item=$\(item.price), expected=$\(expectedSubtotal), diff=\(percentDiff)%")

        if percentDiff < 2.0 {
            return ClassificationResult(
                category: .subtotal,
                confidence: 0.92,
                method: .heuristic,
                reasoning: "Price matches expected subtotal (within \(String(format: "%.1f", percentDiff))%)"
            )
        }

        // Close match but not exact
        if percentDiff < 5.0 {
            return ClassificationResult(
                category: .subtotal,
                confidence: 0.70,
                method: .heuristic,
                reasoning: "Price close to expected subtotal (within \(String(format: "%.1f", percentDiff))%)"
            )
        }

        return nil
    }

    // MARK: - Price Magnitude Analysis

    /// Classify items by comparing price to subtotal magnitude
    private func classifyByPriceMagnitude(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        guard let subtotal = context.subtotalAmount, subtotal > 0 else { return nil }

        let priceRatio = item.price / subtotal
        print("    📏 Price ratio to subtotal: \(priceRatio)")

        // Very small charge (< 15% of subtotal) - likely tax or fee
        if priceRatio < 0.15 && priceRatio > 0.02 {
            let itemName = item.name.lowercased()

            // Tax-like magnitude (5-12%)
            if priceRatio >= 0.05 && priceRatio <= 0.12 {
                if !itemName.contains("tip") && !itemName.contains("grat") {
                    return ClassificationResult(
                        category: .tax,
                        confidence: 0.55,
                        method: .heuristic,
                        reasoning: "Price magnitude (\(String(format: "%.1f", priceRatio * 100))% of subtotal) typical for tax"
                    )
                }
            }

            // Service charge magnitude (2-5%)
            if priceRatio >= 0.02 && priceRatio < 0.05 {
                return ClassificationResult(
                    category: .serviceCharge,
                    confidence: 0.50,
                    method: .heuristic,
                    reasoning: "Small charge (\(String(format: "%.1f", priceRatio * 100))% of subtotal) likely service fee"
                )
            }
        }

        // Medium charge (15-30% of subtotal) - likely tip or significant fee
        if priceRatio >= 0.15 && priceRatio <= 0.30 {
            let itemName = item.name.lowercased()

            if itemName.contains("tip") || itemName.contains("grat") || itemName.contains("service") {
                return ClassificationResult(
                    category: .tip,
                    confidence: 0.60,
                    method: .heuristic,
                    reasoning: "Price magnitude (\(String(format: "%.1f", priceRatio * 100))% of subtotal) typical for tip"
                )
            }
        }

        // Large charge (> 50% of subtotal) - likely total or subtotal itself
        if priceRatio >= 0.50 {
            let itemName = item.name.lowercased()

            if itemName.contains("total") {
                return ClassificationResult(
                    category: priceRatio < 0.80 ? .subtotal : .total,
                    confidence: 0.65,
                    method: .heuristic,
                    reasoning: "Large price (\(String(format: "%.1f", priceRatio * 100))% of subtotal) likely total/subtotal"
                )
            }
        }

        // Normal food item range (5-50% of subtotal, not matching other patterns)
        if priceRatio >= 0.05 && priceRatio <= 0.50 {
            return ClassificationResult(
                category: .food,
                confidence: 0.50,
                method: .heuristic,
                reasoning: "Price in typical food item range"
            )
        }

        return nil
    }
}
