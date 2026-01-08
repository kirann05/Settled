//
//  GeometricClassificationStrategy.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

/// Position-based classification strategy
/// Uses item position in receipt to infer category (e.g., last lines are totals)
class GeometricClassificationStrategy: ClassificationStrategy {
    private let config: ClassificationConfig

    init(config: ClassificationConfig = .default) {
        self.config = config
    }

    func canClassify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) -> Bool {
        // Can classify any item based on position
        return true
    }

    func classify(_ item: ReceiptItem, at position: Int, context: ReceiptContext) async -> ClassificationResult {
        let totalItems = context.itemCount

        // Determine receipt zones
        let headerZoneEnd = Int(Double(totalItems) * 0.20)      // Top 20%
        let itemZoneEnd = Int(Double(totalItems) * 0.80)        // Next 60%
        let summaryZoneStart = itemZoneEnd                      // Bottom 20%

        let isInHeader = position < headerZoneEnd
        let isInItemZone = position >= headerZoneEnd && position < itemZoneEnd
        let isInSummaryZone = position >= summaryZoneStart

        print("  📍 Position: \(position)/\(totalItems) - Zone: \(isInHeader ? "HEADER" : isInItemZone ? "ITEMS" : "SUMMARY")")

        // Header zone: Skip (store info, date, etc.)
        if isInHeader {
            return ClassificationResult(
                category: .unknown,
                confidence: 0.3,
                method: .geometric,
                reasoning: "In header zone, likely store info"
            )
        }

        // Summary zone: Financial summary lines
        if isInSummaryZone {
            return classifySummaryZoneItem(item, position: position, totalItems: totalItems, context: context)
        }

        // Item zone: Food items
        if isInItemZone {
            return classifyItemZoneItem(item, position: position, context: context)
        }

        // Fallback
        return ClassificationResult(
            category: .unknown,
            confidence: 0.2,
            method: .geometric,
            reasoning: "Could not determine zone"
        )
    }

    // MARK: - Summary Zone Classification

    private func classifySummaryZoneItem(
        _ item: ReceiptItem,
        position: Int,
        totalItems: Int,
        context: ReceiptContext
    ) -> ClassificationResult {
        let distanceFromEnd = totalItems - position - 1  // 0 = last line

        // Last line with highest price → likely TOTAL
        if distanceFromEnd == 0 {
            if let expectedTotal = context.expectedTotal,
               abs(item.price - expectedTotal) < 1.0 {
                return ClassificationResult(
                    category: .total,
                    confidence: 0.95,
                    method: .geometric,
                    reasoning: "Last line, matches expected total"
                )
            }

            // Last line but no expected total
            return ClassificationResult(
                category: .total,
                confidence: 0.85,
                method: .geometric,
                reasoning: "Last line, likely total"
            )
        }

        // Second to last line → could be tip or tax
        if distanceFromEnd == 1 {
            let itemName = item.name.lowercased()

            if itemName.contains("tip") || itemName.contains("gratuity") {
                return ClassificationResult(
                    category: itemName.contains("grat") || item.containsPercentage ? .gratuity : .tip,
                    confidence: 0.80,
                    method: .geometric,
                    reasoning: "Near end, contains tip/gratuity keyword"
                )
            }

            if itemName.contains("tax") {
                return ClassificationResult(
                    category: .tax,
                    confidence: 0.80,
                    method: .geometric,
                    reasoning: "Near end, contains tax keyword"
                )
            }

            // Generic near-end item
            return ClassificationResult(
                category: .unknown,
                confidence: 0.5,
                method: .geometric,
                reasoning: "Near end but no clear keyword"
            )
        }

        // Third to last line → could be subtotal, tax, or tip
        if distanceFromEnd == 2 {
            let itemName = item.name.lowercased()

            if itemName.contains("subtotal") || itemName.contains("sub total") {
                return ClassificationResult(
                    category: .subtotal,
                    confidence: 0.85,
                    method: .geometric,
                    reasoning: "Near end, contains subtotal keyword"
                )
            }

            if itemName.contains("tax") {
                return ClassificationResult(
                    category: .tax,
                    confidence: 0.75,
                    method: .geometric,
                    reasoning: "Near end, contains tax keyword"
                )
            }

            if itemName.contains("tip") || itemName.contains("gratuity") || itemName.contains("service") {
                return ClassificationResult(
                    category: item.containsPercentage ? .gratuity : .serviceCharge,
                    confidence: 0.70,
                    method: .geometric,
                    reasoning: "Near end, contains service/tip keyword"
                )
            }

            return ClassificationResult(
                category: .unknown,
                confidence: 0.4,
                method: .geometric,
                reasoning: "In summary zone but no clear category"
            )
        }

        // 4-6 lines from end → could be subtotal or additional charges
        if distanceFromEnd >= 3 && distanceFromEnd <= 5 {
            let itemName = item.name.lowercased()

            if itemName.contains("subtotal") {
                return ClassificationResult(
                    category: .subtotal,
                    confidence: 0.80,
                    method: .geometric,
                    reasoning: "Contains subtotal keyword"
                )
            }

            if itemName.contains("discount") || itemName.contains("coupon") || item.isNegativePrice {
                return ClassificationResult(
                    category: .discount,
                    confidence: 0.75,
                    method: .geometric,
                    reasoning: "Discount keyword or negative price"
                )
            }

            if itemName.contains("delivery") || itemName.contains("shipping") {
                return ClassificationResult(
                    category: .deliveryFee,
                    confidence: 0.75,
                    method: .geometric,
                    reasoning: "Contains delivery/shipping keyword"
                )
            }

            if itemName.contains("service") || itemName.contains("fee") {
                return ClassificationResult(
                    category: .serviceCharge,
                    confidence: 0.70,
                    method: .geometric,
                    reasoning: "Contains service/fee keyword"
                )
            }

            // Generic summary zone item
            return ClassificationResult(
                category: .unknown,
                confidence: 0.3,
                method: .geometric,
                reasoning: "In summary zone, unclear category"
            )
        }

        // Fallback for summary zone
        return ClassificationResult(
            category: .unknown,
            confidence: 0.2,
            method: .geometric,
            reasoning: "In summary zone but far from end"
        )
    }

    // MARK: - Item Zone Classification

    private func classifyItemZoneItem(
        _ item: ReceiptItem,
        position: Int,
        context: ReceiptContext
    ) -> ClassificationResult {
        let itemName = item.name.lowercased()

        // Check for summary keywords that might appear in item zone
        if itemName.contains("subtotal") || itemName.contains("total") {
            return ClassificationResult(
                category: .subtotal,
                confidence: 0.70,
                method: .geometric,
                reasoning: "Contains total keyword in item zone"
            )
        }

        if itemName.contains("tax") {
            return ClassificationResult(
                category: .tax,
                confidence: 0.60,
                method: .geometric,
                reasoning: "Contains tax keyword in item zone (unusual position)"
            )
        }

        if itemName.contains("tip") || itemName.contains("gratuity") {
            return ClassificationResult(
                category: item.containsPercentage ? .gratuity : .tip,
                confidence: 0.60,
                method: .geometric,
                reasoning: "Contains tip keyword in item zone (unusual position)"
            )
        }

        // Check for discount indicators
        if itemName.contains("discount") || itemName.contains("coupon") || itemName.contains("promo") || item.isNegativePrice {
            return ClassificationResult(
                category: .discount,
                confidence: 0.75,
                method: .geometric,
                reasoning: "Discount keyword or negative price"
            )
        }

        // Check for delivery/service charges
        if itemName.contains("delivery") || itemName.contains("shipping") {
            return ClassificationResult(
                category: .deliveryFee,
                confidence: 0.70,
                method: .geometric,
                reasoning: "Delivery/shipping keyword"
            )
        }

        if itemName.contains("service charge") || itemName.contains("service fee") {
            return ClassificationResult(
                category: .serviceCharge,
                confidence: 0.70,
                method: .geometric,
                reasoning: "Service charge keyword"
            )
        }

        // Quantity indicator → likely food item
        if item.startsWithQuantity {
            return ClassificationResult(
                category: .food,
                confidence: 0.85,
                method: .geometric,
                reasoning: "Starts with quantity (e.g., '2 Burgers')"
            )
        }

        // Reasonable price for food item
        if item.price > 1.0 && item.price < 100.0 {
            return ClassificationResult(
                category: .food,
                confidence: 0.75,
                method: .geometric,
                reasoning: "In item zone with reasonable food price"
            )
        }

        // Very small price → could be tax or add-on
        if item.isSmallPrice {
            return ClassificationResult(
                category: .unknown,
                confidence: 0.4,
                method: .geometric,
                reasoning: "Very small price, unclear category"
            )
        }

        // Very large price → could be subtotal
        if item.price > 100.0 {
            return ClassificationResult(
                category: .unknown,
                confidence: 0.3,
                method: .geometric,
                reasoning: "Unusually high price for individual item"
            )
        }

        // Default: assume food item in item zone
        return ClassificationResult(
            category: .food,
            confidence: 0.65,
            method: .geometric,
            reasoning: "In item zone, default to food"
        )
    }
}
