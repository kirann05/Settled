//
//  PatternHeuristicStrategy.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

/// Pattern-based classification strategy
/// Uses text patterns, abbreviations, and formatting to classify items
class PatternHeuristicStrategy: ClassificationStrategy {
    private let config: ClassificationConfig

    init(config: ClassificationConfig = .default) {
        self.config = config
    }

    func canClassify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) -> Bool {
        // Can classify any item with pattern analysis
        return true
    }

    func classify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) async -> ClassificationResult {
        print("  🔍 Pattern Analysis: '\(item.name)'")

        // Check patterns in order of specificity

        // 1. Percentage patterns (highest priority for gratuity/tax)
        if let percentageResult = classifyPercentagePattern(item) {
            return percentageResult
        }

        // 2. Quantity patterns (high priority for food items)
        if let quantityResult = classifyQuantityPattern(item) {
            return quantityResult
        }

        // 3. Negative price patterns (discounts)
        if let negativePriceResult = classifyNegativePricePattern(item) {
            return negativePriceResult
        }

        // 4. Keyword patterns (tax, tip, total, etc.)
        if let keywordResult = classifyKeywordPattern(item, context: context) {
            return keywordResult
        }

        // 5. Abbreviation patterns
        if let abbreviationResult = classifyAbbreviationPattern(item) {
            return abbreviationResult
        }

        // 6. Price magnitude patterns
        if let priceResult = classifyPriceMagnitudePattern(item, context: context) {
            return priceResult
        }

        // No clear pattern found
        return ClassificationResult(
            category: .unknown,
            confidence: 0.1,
            method: .heuristic,
            reasoning: "No clear pattern detected"
        )
    }

    // MARK: - Pattern Classification Methods

    /// Classify items with percentage indicators
    private func classifyPercentagePattern(_ item: ReceiptItem) -> ClassificationResult? {
        guard item.containsPercentage else { return nil }

        let itemName = item.name.lowercased()
        let percentage = item.extractPercentage()

        print("    📊 Percentage detected: \(percentage ?? 0)%")

        // Auto-gratuity patterns
        if itemName.contains("grat") || itemName.contains("party") || itemName.contains("auto") || itemName.contains("service") {
            return ClassificationResult(
                category: .gratuity,
                confidence: 0.95,
                method: .heuristic,
                reasoning: "Contains percentage and gratuity keywords"
            )
        }

        // Tax patterns with percentage (less common but possible)
        if itemName.contains("tax") || itemName.contains("vat") || itemName.contains("gst") || itemName.contains("hst") {
            return ClassificationResult(
                category: .tax,
                confidence: 0.90,
                method: .heuristic,
                reasoning: "Contains percentage and tax keywords"
            )
        }

        // Discount patterns with percentage
        if itemName.contains("discount") || itemName.contains("off") || itemName.contains("sale") {
            return ClassificationResult(
                category: .discount,
                confidence: 0.88,
                method: .heuristic,
                reasoning: "Contains percentage and discount keywords"
            )
        }

        // Generic percentage (likely gratuity if 15-25%)
        if let pct = percentage, pct >= 15 && pct <= 25 {
            return ClassificationResult(
                category: .gratuity,
                confidence: 0.80,
                method: .heuristic,
                reasoning: "Percentage in typical gratuity range (15-25%)"
            )
        }

        // Generic percentage (likely tax if 5-15%)
        if let pct = percentage, pct >= 5 && pct <= 15 {
            return ClassificationResult(
                category: .tax,
                confidence: 0.70,
                method: .heuristic,
                reasoning: "Percentage in typical tax range (5-15%)"
            )
        }

        return nil
    }

    /// Classify items with quantity indicators
    private func classifyQuantityPattern(_ item: ReceiptItem) -> ClassificationResult? {
        guard item.startsWithQuantity else { return nil }

        let quantity = item.extractQuantity() ?? 1
        print("    🔢 Quantity detected: \(quantity)")

        // Items with quantity are almost always food items
        return ClassificationResult(
            category: .food,
            confidence: 0.90,
            method: .heuristic,
            reasoning: "Starts with quantity indicator (e.g., '2 Burgers')"
        )
    }

    /// Classify items with negative prices
    private func classifyNegativePricePattern(_ item: ReceiptItem) -> ClassificationResult? {
        guard item.isNegativePrice else { return nil }

        print("    💸 Negative price detected: $\(item.price)")

        let itemName = item.name.lowercased()

        // Explicit discount keywords
        if itemName.contains("discount") || itemName.contains("coupon") || itemName.contains("promo") ||
           itemName.contains("refund") || itemName.contains("credit") {
            return ClassificationResult(
                category: .discount,
                confidence: 0.95,
                method: .heuristic,
                reasoning: "Negative price with discount keyword"
            )
        }

        // Generic negative price
        return ClassificationResult(
            category: .discount,
            confidence: 0.85,
            method: .heuristic,
            reasoning: "Negative price indicates discount/refund"
        )
    }

    /// Classify items by keyword matching
    private func classifyKeywordPattern(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        let itemName = item.name.lowercased()

        // TAX keywords (multiple languages)
        let taxKeywords = ["tax", "vat", "gst", "hst", "sales tax", "consumption tax", "tva", "iva", "mwst", "税"]
        if taxKeywords.contains(where: { itemName.contains($0) }) {
            return ClassificationResult(
                category: .tax,
                confidence: 0.92,
                method: .heuristic,
                reasoning: "Contains tax keyword"
            )
        }

        // TIP keywords (multiple languages)
        let tipKeywords = ["tip", "pourboire", "propina", "trinkgeld", "チップ"]
        if tipKeywords.contains(where: { itemName.contains($0) }) && !item.containsPercentage {
            return ClassificationResult(
                category: .tip,
                confidence: 0.90,
                method: .heuristic,
                reasoning: "Contains tip keyword (no percentage)"
            )
        }

        // GRATUITY keywords
        let gratuityKeywords = ["gratuity", "auto grat", "service charge", "large party", "party charge"]
        if gratuityKeywords.contains(where: { itemName.contains($0) }) {
            return ClassificationResult(
                category: .gratuity,
                confidence: 0.93,
                method: .heuristic,
                reasoning: "Contains gratuity/auto-tip keyword"
            )
        }

        // TOTAL keywords
        let totalKeywords = ["total", "amount due", "balance", "grand total"]
        if totalKeywords.contains(where: { itemName.contains($0) }) && !itemName.contains("sub") {
            return ClassificationResult(
                category: .total,
                confidence: 0.88,
                method: .heuristic,
                reasoning: "Contains total keyword"
            )
        }

        // SUBTOTAL keywords
        let subtotalKeywords = ["subtotal", "sub total", "sub-total", "items total"]
        if subtotalKeywords.contains(where: { itemName.contains($0) }) {
            return ClassificationResult(
                category: .subtotal,
                confidence: 0.90,
                method: .heuristic,
                reasoning: "Contains subtotal keyword"
            )
        }

        // DISCOUNT keywords
        let discountKeywords = ["discount", "coupon", "promo", "sale", "off", "savings"]
        if discountKeywords.contains(where: { itemName.contains($0) }) {
            return ClassificationResult(
                category: .discount,
                confidence: 0.85,
                method: .heuristic,
                reasoning: "Contains discount keyword"
            )
        }

        // DELIVERY keywords
        let deliveryKeywords = ["delivery", "shipping", "postage", "freight"]
        if deliveryKeywords.contains(where: { itemName.contains($0) }) {
            return ClassificationResult(
                category: .deliveryFee,
                confidence: 0.88,
                method: .heuristic,
                reasoning: "Contains delivery/shipping keyword"
            )
        }

        // SERVICE CHARGE keywords (not gratuity)
        let serviceKeywords = ["service fee", "processing fee", "convenience fee", "handling"]
        if serviceKeywords.contains(where: { itemName.contains($0) }) {
            return ClassificationResult(
                category: .serviceCharge,
                confidence: 0.85,
                method: .heuristic,
                reasoning: "Contains service charge keyword"
            )
        }

        return nil
    }

    /// Classify items by abbreviation patterns
    private func classifyAbbreviationPattern(_ item: ReceiptItem) -> ClassificationResult? {
        let itemName = item.name.trimmingCharacters(in: .whitespaces)

        // Very short names (2-3 characters) - likely abbreviations
        if itemName.count <= 3 {
            let lowercased = itemName.lowercased()

            // Known tax abbreviations
            if lowercased == "tax" || lowercased == "vat" || lowercased == "gst" || lowercased == "hst" || lowercased == "tx" {
                return ClassificationResult(
                    category: .tax,
                    confidence: 0.85,
                    method: .heuristic,
                    reasoning: "Short tax abbreviation"
                )
            }

            // Known tip abbreviations
            if lowercased == "tip" {
                return ClassificationResult(
                    category: .tip,
                    confidence: 0.85,
                    method: .heuristic,
                    reasoning: "Short tip abbreviation"
                )
            }

            // Other short names - low confidence, likely POS codes
            return ClassificationResult(
                category: .unknown,
                confidence: 0.3,
                method: .heuristic,
                reasoning: "Very short name, likely POS code"
            )
        }

        // All uppercase names (POS system codes)
        if item.isAllUppercase && itemName.count > 3 && itemName.count < 15 {
            // Check if it's a summary keyword
            let lowercased = itemName.lowercased()
            if lowercased.contains("total") || lowercased.contains("subtotal") ||
               lowercased.contains("tax") || lowercased.contains("tip") {
                return nil  // Let keyword pattern handle it
            }

            // Likely a food item code
            return ClassificationResult(
                category: .food,
                confidence: 0.60,
                method: .heuristic,
                reasoning: "All-caps POS code, likely food item"
            )
        }

        return nil
    }

    /// Classify items by price magnitude
    private func classifyPriceMagnitudePattern(_ item: ReceiptItem, context: ReceiptContext) -> ClassificationResult? {
        // Very small prices (< $1)
        if item.isSmallPrice {
            // Could be tax on low-cost items or add-on charge
            if let expectedTotal = context.expectedTotal, expectedTotal > 10.0 {
                // Small price on large receipt → likely tax
                return ClassificationResult(
                    category: .tax,
                    confidence: 0.50,
                    method: .heuristic,
                    reasoning: "Very small price, possibly tax"
                )
            }

            // Small price, unclear
            return ClassificationResult(
                category: .unknown,
                confidence: 0.3,
                method: .heuristic,
                reasoning: "Very small price, unclear category"
            )
        }

        // Very large prices (> $100)
        if item.price > 100.0 {
            if let expectedTotal = context.expectedTotal, abs(item.price - expectedTotal) < 5.0 {
                // Close to expected total
                return ClassificationResult(
                    category: .total,
                    confidence: 0.75,
                    method: .heuristic,
                    reasoning: "Large price close to expected total"
                )
            }

            // Large price, could be subtotal
            return ClassificationResult(
                category: .subtotal,
                confidence: 0.55,
                method: .heuristic,
                reasoning: "Large price, possibly subtotal"
            )
        }

        // Medium prices ($1-$100) - typical food item range
        if item.price >= 1.0 && item.price <= 100.0 {
            return ClassificationResult(
                category: .food,
                confidence: 0.75,
                method: .heuristic,
                reasoning: "Price in typical food item range"
            )
        }

        return nil
    }
}
