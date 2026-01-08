//
//  ReceiptClassifier.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

/// Main receipt classifier orchestrating all classification strategies
class ReceiptClassifier: ReceiptClassificationService {
    private let config: ClassificationConfig
    private let strategyChain: ClassificationStrategyChain
    private let validator: ReceiptValidator

    init(config: ClassificationConfig = .geminiFirst) {
        self.config = config
        self.validator = ReceiptValidator(config: config)

        // Build strategy chain: fast → slow, cheap → expensive
        let strategies: [ClassificationStrategy] = [
            // 1. Geometric (position-based) - fastest, free
            GeometricClassificationStrategy(config: config),

            // 2. Pattern heuristics (keywords, formats) - fast, free
            PatternHeuristicStrategy(config: config),

            // 3. Price relationships (math validation) - fast, free
            PriceRelationshipStrategy(config: config),

            // 4. Gemini LLM (fallback for low confidence) - slow, costly
            GeminiClassificationStrategy(config: config)
        ]

        self.strategyChain = ClassificationStrategyChain(strategies: strategies, config: config)
    }

    // MARK: - Main Classification Interface

    func classify(_ items: [ReceiptItem], context: ReceiptContext) async -> ClassifiedReceipt {
        print("🧠 Starting receipt classification")
        print("   Receipt type: \(context.receiptType.rawValue)")
        print("   Total items: \(context.itemCount)")
        print("   Expected total: \(context.totalAmount.map { String(format: "$%.2f", $0) } ?? "unknown")")

        // Classify each item using strategy chain
        var classifiedItems: [ClassifiedReceiptItem] = []

        for (index, item) in items.enumerated() {
            print("\n🔍 Classifying item \(index + 1)/\(items.count): '\(item.name)' ($\(item.price))")

            let result = await strategyChain.classify(item, at: index, context: context)

            let classifiedItem = ClassifiedReceiptItem(
                id: UUID().uuidString,
                name: item.name,
                price: item.price,
                category: result.category,
                classificationConfidence: result.confidence,
                classificationMethod: result.method,
                originalText: item.name,
                position: index,
                createdAt: Date(),
                updatedAt: Date(),
                correctedBy: nil,
                correctedAt: nil
            )

            classifiedItems.append(classifiedItem)

            print("   ✅ Classified as: \(result.category.displayName) (confidence: \(String(format: "%.2f", result.confidence)))")
            print("   📝 Reasoning: \(result.reasoning)")
        }

        // Organize items by category
        let organizedReceipt = organizeItems(classifiedItems)

        // Validate the classified receipt
        let validatedReceipt = validator.validate(organizedReceipt, context: context)

        // Log summary
        logClassificationSummary(validatedReceipt)

        return validatedReceipt
    }

    // MARK: - Item Organization

    private func organizeItems(_ items: [ClassifiedReceiptItem]) -> ClassifiedReceipt {
        var foodItems: [ClassifiedReceiptItem] = []
        var tax: ClassifiedReceiptItem?
        var tip: ClassifiedReceiptItem?
        var gratuity: ClassifiedReceiptItem?
        var subtotal: ClassifiedReceiptItem?
        var total: ClassifiedReceiptItem?
        var discounts: [ClassifiedReceiptItem] = []
        var otherCharges: [ClassifiedReceiptItem] = []
        var unknownItems: [ClassifiedReceiptItem] = []

        for item in items {
            switch item.category {
            case .food:
                foodItems.append(item)
            case .tax:
                // Keep highest confidence tax item
                if let existingTax = tax {
                    tax = item.classificationConfidence > existingTax.classificationConfidence ? item : existingTax
                } else {
                    tax = item
                }
            case .tip:
                // Keep highest confidence tip item
                if let existingTip = tip {
                    tip = item.classificationConfidence > existingTip.classificationConfidence ? item : existingTip
                } else {
                    tip = item
                }
            case .gratuity:
                // Keep highest confidence gratuity item
                if let existingGratuity = gratuity {
                    gratuity = item.classificationConfidence > existingGratuity.classificationConfidence ? item : existingGratuity
                } else {
                    gratuity = item
                }
            case .subtotal:
                // Keep highest confidence subtotal
                if let existingSubtotal = subtotal {
                    subtotal = item.classificationConfidence > existingSubtotal.classificationConfidence ? item : existingSubtotal
                } else {
                    subtotal = item
                }
            case .total:
                // Keep highest confidence total
                if let existingTotal = total {
                    total = item.classificationConfidence > existingTotal.classificationConfidence ? item : existingTotal
                } else {
                    total = item
                }
            case .discount:
                discounts.append(item)
            case .serviceCharge, .deliveryFee:
                otherCharges.append(item)
            case .unknown:
                unknownItems.append(item)
            }
        }

        // Calculate overall confidence
        let totalConfidence = items.isEmpty ? 0.0 : items.map { $0.classificationConfidence }.reduce(0, +) / Double(items.count)

        return ClassifiedReceipt(
            foodItems: foodItems.sorted { $0.position < $1.position },
            tax: tax,
            tip: tip,
            gratuity: gratuity,
            subtotal: subtotal,
            total: total,
            discounts: discounts.sorted { $0.position < $1.position },
            otherCharges: otherCharges.sorted { $0.position < $1.position },
            unknownItems: unknownItems.sorted { $0.position < $1.position },
            totalConfidence: totalConfidence,
            validationStatus: .valid,  // Will be updated by validator
            validationIssues: []  // Will be populated by validator
        )
    }

    // MARK: - Logging

    private func logClassificationSummary(_ receipt: ClassifiedReceipt) {
        print("\n📊 Classification Summary:")
        print("   Food items: \(receipt.foodItems.count)")
        print("   Tax: \(receipt.tax != nil ? "✅" : "❌")")
        print("   Tip: \(receipt.tip != nil ? "✅" : "❌")")
        print("   Gratuity: \(receipt.gratuity != nil ? "✅" : "❌")")
        print("   Subtotal: \(receipt.subtotal != nil ? "✅" : "❌")")
        print("   Total: \(receipt.total != nil ? "✅" : "❌")")
        print("   Discounts: \(receipt.discounts.count)")
        print("   Other charges: \(receipt.otherCharges.count)")
        print("   Unknown: \(receipt.unknownItems.count)")
        print("   Overall confidence: \(String(format: "%.1f%%", receipt.totalConfidence * 100))")
        print("   Validation status: \(receipt.validationStatus.rawValue)")

        if !receipt.validationIssues.isEmpty {
            print("\n⚠️ Validation Issues:")
            for issue in receipt.validationIssues {
                print("   - [\(issue.severity.rawValue)] \(issue.message)")
            }
        }

        print("\n✅ Classification complete\n")
    }
}

// MARK: - Receipt Validator

/// Validates classified receipts for mathematical consistency
class ReceiptValidator {
    private let config: ClassificationConfig

    init(config: ClassificationConfig) {
        self.config = config
    }

    func validate(_ receipt: ClassifiedReceipt, context: ReceiptContext) -> ClassifiedReceipt {
        var issues: [ValidationIssue] = []

        // 1. Sum validation: food items + charges - discounts should ≈ subtotal
        if let subtotalIssue = validateSubtotalSum(receipt) {
            issues.append(subtotalIssue)
        }

        // 2. Total validation: subtotal + tax + tip + gratuity should ≈ total
        if let totalIssue = validateTotalSum(receipt) {
            issues.append(totalIssue)
        }

        // 3. Tax rate validation
        if let taxIssue = validateTaxRate(receipt, context: context) {
            issues.append(taxIssue)
        }

        // 4. Tip rate validation
        if let tipIssue = validateTipRate(receipt) {
            issues.append(tipIssue)
        }

        // 5. Missing critical items
        if let missingIssues = validateMissingItems(receipt) {
            issues.append(contentsOf: missingIssues)
        }

        // 6. Low confidence items
        if let confidenceIssues = validateConfidence(receipt) {
            issues.append(contentsOf: confidenceIssues)
        }

        // Determine overall validation status
        let status = determineValidationStatus(issues: issues)

        return ClassifiedReceipt(
            foodItems: receipt.foodItems,
            tax: receipt.tax,
            tip: receipt.tip,
            gratuity: receipt.gratuity,
            subtotal: receipt.subtotal,
            total: receipt.total,
            discounts: receipt.discounts,
            otherCharges: receipt.otherCharges,
            unknownItems: receipt.unknownItems,
            totalConfidence: receipt.totalConfidence,
            validationStatus: status,
            validationIssues: issues
        )
    }

    // MARK: - Validation Checks

    private func validateSubtotalSum(_ receipt: ClassifiedReceipt) -> ValidationIssue? {
        guard let subtotal = receipt.subtotal else { return nil }

        let calculatedSubtotal = receipt.foodItemsSum() + receipt.otherCharges.reduce(0.0) { $0.currencyAdd($1.price) }
        let discountTotal = receipt.discounts.reduce(0.0) { $0.currencyAdd(abs($1.price)) }
        let expectedSubtotal = calculatedSubtotal.currencySubtract(discountTotal)

        let difference = abs(subtotal.price - expectedSubtotal)
        let tolerance = 0.02  // 2 cents tolerance for rounding

        if difference > tolerance {
            return ValidationIssue(
                type: .subtotalMismatch,
                message: "Subtotal ($\(String(format: "%.2f", subtotal.price))) doesn't match calculated sum ($\(String(format: "%.2f", expectedSubtotal)))",
                severity: .warning,
                affectedItemIds: [subtotal.id]
            )
        }

        return nil
    }

    private func validateTotalSum(_ receipt: ClassifiedReceipt) -> ValidationIssue? {
        guard let total = receipt.total else { return nil }

        let subtotalAmount = receipt.subtotal?.price ?? receipt.foodItemsSum()
        let taxAmount = receipt.tax?.price ?? 0.0
        let tipAmount = receipt.tip?.price ?? 0.0
        let gratuityAmount = receipt.gratuity?.price ?? 0.0
        let chargesAmount = receipt.otherCharges.reduce(0.0) { $0.currencyAdd($1.price) }
        let discountAmount = receipt.discounts.reduce(0.0) { $0.currencyAdd(abs($1.price)) }

        let expectedTotal = subtotalAmount
            .currencyAdd(taxAmount)
            .currencyAdd(tipAmount)
            .currencyAdd(gratuityAmount)
            .currencyAdd(chargesAmount)
            .currencySubtract(discountAmount)

        let difference = abs(total.price - expectedTotal)
        let tolerance = 0.02  // 2 cents tolerance

        if difference > tolerance {
            return ValidationIssue(
                type: .sumMismatch,
                message: "Total ($\(String(format: "%.2f", total.price))) doesn't match calculated sum ($\(String(format: "%.2f", expectedTotal)))",
                severity: .warning,
                affectedItemIds: [total.id]
            )
        }

        return nil
    }

    private func validateTaxRate(_ receipt: ClassifiedReceipt, context: ReceiptContext) -> ValidationIssue? {
        guard let tax = receipt.tax else { return nil }

        let subtotalAmount = receipt.subtotal?.price ?? receipt.foodItemsSum()
        guard subtotalAmount > 0 else { return nil }

        let taxRate = (tax.price / subtotalAmount) * 100.0
        let expectedRange = context.receiptType.typicalTaxRange
        let expectedRangePercent = (expectedRange.lowerBound * 100)...(expectedRange.upperBound * 100)

        if !expectedRangePercent.contains(taxRate) {
            return ValidationIssue(
                type: .invalidTaxRate,
                message: "Tax rate (\(String(format: "%.1f", taxRate))%) outside expected range for \(context.receiptType.rawValue) (\(String(format: "%.0f", expectedRangePercent.lowerBound))-\(String(format: "%.0f", expectedRangePercent.upperBound))%)",
                severity: .warning,
                affectedItemIds: [tax.id]
            )
        }

        return nil
    }

    private func validateTipRate(_ receipt: ClassifiedReceipt) -> ValidationIssue? {
        guard let tip = receipt.tip else { return nil }

        let subtotalAmount = receipt.subtotal?.price ?? receipt.foodItemsSum()
        guard subtotalAmount > 0 else { return nil }

        let tipRate = (tip.price / subtotalAmount) * 100.0
        let typicalRange = 10.0...30.0

        if !typicalRange.contains(tipRate) {
            return ValidationIssue(
                type: .invalidTipRate,
                message: "Tip rate (\(String(format: "%.1f", tipRate))%) outside typical range (10-30%)",
                severity: .warning,
                affectedItemIds: [tip.id]
            )
        }

        return nil
    }

    private func validateMissingItems(_ receipt: ClassifiedReceipt) -> [ValidationIssue]? {
        var issues: [ValidationIssue] = []

        if receipt.total == nil {
            issues.append(ValidationIssue(
                type: .missingTotal,
                message: "No total amount detected",
                severity: .warning,
                affectedItemIds: []
            ))
        }

        if receipt.tax == nil {
            issues.append(ValidationIssue(
                type: .invalidTaxRate,
                message: "No tax detected",
                severity: .warning,
                affectedItemIds: []
            ))
        }

        if receipt.foodItems.isEmpty {
            issues.append(ValidationIssue(
                type: .missingTotal,
                message: "No food items detected",
                severity: .invalid,
                affectedItemIds: []
            ))
        }

        return issues.isEmpty ? nil : issues
    }

    private func validateConfidence(_ receipt: ClassifiedReceipt) -> [ValidationIssue]? {
        let lowConfidenceItems = receipt.allItems.filter { $0.needsReview }

        guard !lowConfidenceItems.isEmpty else { return nil }

        return [ValidationIssue(
            type: .outlierPrice,
            message: "\(lowConfidenceItems.count) item(s) need manual review (low confidence)",
            severity: .needsReview,
            affectedItemIds: lowConfidenceItems.map { $0.id }
        )]
    }

    private func determineValidationStatus(issues: [ValidationIssue]) -> ValidationStatus {
        let hasInvalid = issues.contains { $0.severity == .invalid }
        let hasWarning = issues.contains { $0.severity == .warning }

        if hasInvalid {
            return .invalid
        } else if hasWarning {
            return .warning
        } else if !issues.isEmpty {
            return .needsReview
        } else {
            return .valid
        }
    }
}
