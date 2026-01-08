//
//  ReceiptClassificationModels.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

// MARK: - Item Category

/// Categories for classifying receipt line items
enum ItemCategory: String, Codable, CaseIterable {
    case food = "FOOD"
    case tax = "TAX"
    case tip = "TIP"
    case gratuity = "GRATUITY"              // Auto-added gratuity (mandatory)
    case subtotal = "SUBTOTAL"
    case total = "TOTAL"
    case discount = "DISCOUNT"
    case serviceCharge = "SERVICE_CHARGE"
    case deliveryFee = "DELIVERY_FEE"
    case unknown = "UNKNOWN"

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .food: return "Food Item"
        case .tax: return "Tax"
        case .tip: return "Tip"
        case .gratuity: return "Auto-Gratuity"
        case .subtotal: return "Subtotal"
        case .total: return "Total"
        case .discount: return "Discount"
        case .serviceCharge: return "Service Charge"
        case .deliveryFee: return "Delivery Fee"
        case .unknown: return "Unknown"
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .tax: return "percent"
        case .tip: return "dollarsign.circle"
        case .gratuity: return "dollarsign.circle.fill"
        case .subtotal: return "sum"
        case .total: return "checkmark.circle.fill"
        case .discount: return "tag.fill"
        case .serviceCharge: return "briefcase"
        case .deliveryFee: return "shippingbox"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Whether this category represents a charge added to food items
    var isAdditionalCharge: Bool {
        switch self {
        case .tax, .tip, .gratuity, .serviceCharge, .deliveryFee:
            return true
        case .food, .subtotal, .total, .discount, .unknown:
            return false
        }
    }

    /// Whether this category represents a financial summary line
    var isSummaryLine: Bool {
        switch self {
        case .subtotal, .total:
            return true
        case .food, .tax, .tip, .gratuity, .discount, .serviceCharge, .deliveryFee, .unknown:
            return false
        }
    }
}

// MARK: - Classification Method

/// How the item was classified
enum ClassificationMethod: String, Codable {
    case geometric = "GEOMETRIC"        // Position-based heuristic
    case heuristic = "HEURISTIC"        // Pattern-based heuristic
    case priceRelationship = "PRICE_RELATIONSHIP"  // Mathematical relationship
    case llm = "LLM"                    // Gemini LLM classification
    case manual = "MANUAL"              // User correction
}

// MARK: - Classified Receipt Item

/// A receipt item with classification metadata
struct ClassifiedReceiptItem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let price: Double

    // Classification metadata
    let category: ItemCategory
    let classificationConfidence: Double  // 0.0 - 1.0
    let classificationMethod: ClassificationMethod
    let originalText: String              // Raw OCR text
    let position: Int                     // Line position in receipt (0-based)

    // Timestamps
    let createdAt: Date
    var updatedAt: Date

    // Manual correction tracking
    var correctedBy: String?              // User ID if manually corrected
    var correctedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        price: Double,
        category: ItemCategory,
        classificationConfidence: Double,
        classificationMethod: ClassificationMethod,
        originalText: String,
        position: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        correctedBy: String? = nil,
        correctedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.classificationConfidence = classificationConfidence
        self.classificationMethod = classificationMethod
        self.originalText = originalText
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.correctedBy = correctedBy
        self.correctedAt = correctedAt
    }

    /// Create from unclassified ReceiptItem
    init(from item: ReceiptItem, position: Int, category: ItemCategory, confidence: Double, method: ClassificationMethod) {
        self.id = UUID().uuidString
        self.name = item.name
        self.price = item.price
        self.category = category
        self.classificationConfidence = confidence
        self.classificationMethod = method
        self.originalText = item.name  // Use name as original text
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
        self.correctedBy = nil
        self.correctedAt = nil
    }

    /// Create a corrected version of this item
    func corrected(to newCategory: ItemCategory, by userId: String) -> ClassifiedReceiptItem {
        var updated = self
        updated.updatedAt = Date()
        updated.correctedBy = userId
        updated.correctedAt = Date()

        return ClassifiedReceiptItem(
            id: id,
            name: name,
            price: price,
            category: newCategory,
            classificationConfidence: 1.0,  // Manual correction = 100% confidence
            classificationMethod: .manual,
            originalText: originalText,
            position: position,
            createdAt: createdAt,
            updatedAt: updated.updatedAt,
            correctedBy: userId,
            correctedAt: updated.correctedAt
        )
    }

    /// Whether this item needs user review (low confidence)
    var needsReview: Bool {
        return classificationConfidence < 0.7 && classificationMethod != .manual
    }

    /// Confidence level for UI display (using existing ConfidenceLevel from DataModels)
    var confidenceLevel: ConfidenceLevel {
        if classificationMethod == .manual {
            return .high  // Manual corrections are always high confidence
        }

        if classificationConfidence >= 0.9 {
            return .high
        } else if classificationConfidence >= 0.7 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Validation Status

enum ValidationStatus: String, Codable {
    case valid = "VALID"
    case warning = "WARNING"          // Minor issues, likely correct
    case invalid = "INVALID"          // Major issues, needs review
    case needsReview = "NEEDS_REVIEW" // Ambiguous, user should verify
}

// MARK: - Validation Issue

struct ValidationIssue: Codable, Equatable {
    enum IssueType: String, Codable {
        case sumMismatch = "SUM_MISMATCH"
        case invalidTaxRate = "INVALID_TAX_RATE"
        case invalidTipRate = "INVALID_TIP_RATE"
        case duplicateCategory = "DUPLICATE_CATEGORY"
        case missingTotal = "MISSING_TOTAL"
        case negativePrice = "NEGATIVE_PRICE"
        case outlierPrice = "OUTLIER_PRICE"
        case subtotalMismatch = "SUBTOTAL_MISMATCH"
    }

    let type: IssueType
    let message: String
    let severity: ValidationStatus
    let affectedItemIds: [String]

    var displayMessage: String {
        switch type {
        case .sumMismatch:
            return "Items + charges don't match total"
        case .invalidTaxRate:
            return "Tax rate seems unusual"
        case .invalidTipRate:
            return "Tip amount seems unusual"
        case .duplicateCategory:
            return "Multiple items with same category"
        case .missingTotal:
            return "No total found"
        case .negativePrice:
            return "Unexpected negative price"
        case .outlierPrice:
            return "Price seems unusually high/low"
        case .subtotalMismatch:
            return "Subtotal doesn't match item sum"
        }
    }
}

// MARK: - Classified Receipt

/// A complete receipt with classified items and validation
struct ClassifiedReceipt: Codable {
    let id: String

    // Classified items by category
    let foodItems: [ClassifiedReceiptItem]
    let tax: ClassifiedReceiptItem?
    let tip: ClassifiedReceiptItem?
    let gratuity: ClassifiedReceiptItem?
    let subtotal: ClassifiedReceiptItem?
    let total: ClassifiedReceiptItem?
    let discounts: [ClassifiedReceiptItem]
    let otherCharges: [ClassifiedReceiptItem]  // Service charges, delivery fees
    let unknownItems: [ClassifiedReceiptItem]

    // Overall metadata
    let totalConfidence: Double               // Weighted average of all confidences
    let validationStatus: ValidationStatus
    let validationIssues: [ValidationIssue]

    // Timestamps
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        foodItems: [ClassifiedReceiptItem] = [],
        tax: ClassifiedReceiptItem? = nil,
        tip: ClassifiedReceiptItem? = nil,
        gratuity: ClassifiedReceiptItem? = nil,
        subtotal: ClassifiedReceiptItem? = nil,
        total: ClassifiedReceiptItem? = nil,
        discounts: [ClassifiedReceiptItem] = [],
        otherCharges: [ClassifiedReceiptItem] = [],
        unknownItems: [ClassifiedReceiptItem] = [],
        totalConfidence: Double = 0.0,
        validationStatus: ValidationStatus = .needsReview,
        validationIssues: [ValidationIssue] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.foodItems = foodItems
        self.tax = tax
        self.tip = tip
        self.gratuity = gratuity
        self.subtotal = subtotal
        self.total = total
        self.discounts = discounts
        self.otherCharges = otherCharges
        self.unknownItems = unknownItems
        self.totalConfidence = totalConfidence
        self.validationStatus = validationStatus
        self.validationIssues = validationIssues
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// All items in receipt
    var allItems: [ClassifiedReceiptItem] {
        var items = foodItems + discounts + otherCharges + unknownItems
        if let tax = tax { items.append(tax) }
        if let tip = tip { items.append(tip) }
        if let gratuity = gratuity { items.append(gratuity) }
        if let subtotal = subtotal { items.append(subtotal) }
        if let total = total { items.append(total) }
        return items.sorted { $0.position < $1.position }
    }

    /// Items that need user review
    var itemsNeedingReview: [ClassifiedReceiptItem] {
        return allItems.filter { $0.needsReview }
    }

    /// Calculate sum of food items
    func foodItemsSum() -> Double {
        return foodItems.reduce(0.0) { $0 + $1.price }
    }

    /// Calculate total charges (tax + tip + gratuity + other)
    func totalCharges() -> Double {
        var sum = 0.0
        if let tax = tax { sum += tax.price }
        if let tip = tip { sum += tip.price }
        if let gratuity = gratuity { sum += gratuity.price }
        sum += otherCharges.reduce(0.0) { $0 + $1.price }
        return sum
    }

    /// Calculate total discounts
    func totalDiscounts() -> Double {
        return discounts.reduce(0.0) { $0 + $1.price }
    }

    /// Calculate expected total (items + charges - discounts)
    func expectedTotal() -> Double {
        return foodItemsSum() + totalCharges() - totalDiscounts()
    }

    /// Validate that sum matches total
    func sumMatchesTotal(tolerance: Double = 0.01) -> Bool {
        guard let total = total else { return false }
        let expected = expectedTotal()
        let difference = abs(total.price - expected)
        let percentDifference = difference / total.price
        return percentDifference <= tolerance
    }

    /// Get validation status color for UI
    var statusColor: String {
        switch validationStatus {
        case .valid: return "green"
        case .warning: return "yellow"
        case .invalid: return "red"
        case .needsReview: return "orange"
        }
    }

    /// Whether user should review this receipt
    var requiresUserReview: Bool {
        return validationStatus == .invalid ||
               validationStatus == .needsReview ||
               !itemsNeedingReview.isEmpty
    }
}

// MARK: - CustomStringConvertible for Debugging

extension ClassifiedReceiptItem: CustomStringConvertible {
    var description: String {
        return """
        ClassifiedReceiptItem(
          name: "\(name)",
          price: $\(String(format: "%.2f", price)),
          category: \(category.rawValue),
          confidence: \(String(format: "%.2f", classificationConfidence)),
          method: \(classificationMethod.rawValue),
          position: \(position)
        )
        """
    }
}

extension ClassifiedReceipt: CustomStringConvertible {
    var description: String {
        return """
        ClassifiedReceipt(
          foodItems: \(foodItems.count),
          tax: \(tax != nil ? String(format: "$%.2f", tax!.price) : "none"),
          tip: \(tip != nil ? String(format: "$%.2f", tip!.price) : "none"),
          gratuity: \(gratuity != nil ? String(format: "$%.2f", gratuity!.price) : "none"),
          total: \(total != nil ? String(format: "$%.2f", total!.price) : "none"),
          confidence: \(String(format: "%.0f%%", totalConfidence * 100)),
          validation: \(validationStatus.rawValue),
          issues: \(validationIssues.count)
        )
        """
    }
}
