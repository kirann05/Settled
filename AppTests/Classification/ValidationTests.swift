//
//  ValidationTests.swift
//  SettledTests
//
//  Created by Claude on 2025-10-26.
//

import XCTest
@testable import Settled

final class ValidationTests: XCTestCase {

    var validator: ReceiptValidator!

    override func setUp() {
        super.setUp()
        validator = ReceiptValidator(config: .default)
    }

    // MARK: - Sum Validation Tests

    func testValidation_ValidSubtotalSum() {
        let receipt = createReceipt(
            foodItems: [
                createItem(name: "Burger", price: 12.99, category: .food),
                createItem(name: "Fries", price: 4.99, category: .food)
            ],
            subtotal: createItem(name: "Subtotal", price: 17.98, category: .subtotal)
        )

        let context = createContext(subtotalAmount: 17.98, totalAmount: 20.00)
        let validated = validator.validate(receipt, context: context)

        XCTAssertEqual(validated.validationStatus, .valid)
        XCTAssertTrue(validated.validationIssues.isEmpty)
    }

    func testValidation_InvalidSubtotalSum() {
        let receipt = createReceipt(
            foodItems: [
                createItem(name: "Burger", price: 12.99, category: .food),
                createItem(name: "Fries", price: 4.99, category: .food)
            ],
            subtotal: createItem(name: "Subtotal", price: 20.00, category: .subtotal) // Wrong!
        )

        let context = createContext(subtotalAmount: 20.00, totalAmount: 25.00)
        let validated = validator.validate(receipt, context: context)

        XCTAssertNotEqual(validated.validationStatus, .valid)
        XCTAssertFalse(validated.validationIssues.isEmpty)
        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("Subtotal") })
    }

    func testValidation_ValidTotalSum() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 12.99, category: .food)],
            tax: createItem(name: "Tax", price: 1.30, category: .tax),
            tip: createItem(name: "Tip", price: 2.00, category: .tip),
            total: createItem(name: "Total", price: 16.29, category: .total)
        )

        let context = createContext(subtotalAmount: 12.99, totalAmount: 16.29)
        let validated = validator.validate(receipt, context: context)

        XCTAssertEqual(validated.validationStatus, .valid)
        XCTAssertTrue(validated.validationIssues.isEmpty)
    }

    func testValidation_InvalidTotalSum() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 12.99, category: .food)],
            tax: createItem(name: "Tax", price: 1.30, category: .tax),
            tip: createItem(name: "Tip", price: 2.00, category: .tip),
            total: createItem(name: "Total", price: 20.00, category: .total) // Wrong!
        )

        let context = createContext(subtotalAmount: 12.99, totalAmount: 20.00)
        let validated = validator.validate(receipt, context: context)

        XCTAssertNotEqual(validated.validationStatus, .valid)
        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("Total") })
    }

    // MARK: - Tax Rate Validation Tests

    func testValidation_ValidTaxRate() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 50.00, category: .food)],
            tax: createItem(name: "Tax", price: 4.00, category: .tax) // 8% tax
        )

        let context = createContext(
            subtotalAmount: 50.00,
            totalAmount: 54.00,
            receiptType: .restaurant // expects 5-12% tax
        )

        let validated = validator.validate(receipt, context: context)

        // Should not have tax rate warning
        XCTAssertFalse(validated.validationIssues.contains { $0.message.contains("Tax rate") })
    }

    func testValidation_InvalidTaxRate() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 50.00, category: .food)],
            tax: createItem(name: "Tax", price: 10.00, category: .tax) // 20% tax (too high!)
        )

        let context = createContext(
            subtotalAmount: 50.00,
            totalAmount: 60.00,
            receiptType: .restaurant // expects 5-12% tax
        )

        let validated = validator.validate(receipt, context: context)

        // Should have tax rate warning
        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("Tax rate") })
    }

    // MARK: - Tip Rate Validation Tests

    func testValidation_ValidTipRate() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 50.00, category: .food)],
            tip: createItem(name: "Tip", price: 10.00, category: .tip) // 20% tip
        )

        let context = createContext(subtotalAmount: 50.00, totalAmount: 60.00)
        let validated = validator.validate(receipt, context: context)

        // Should not have tip rate warning
        XCTAssertFalse(validated.validationIssues.contains { $0.message.contains("Tip rate") })
    }

    func testValidation_InvalidTipRate() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 50.00, category: .food)],
            tip: createItem(name: "Tip", price: 25.00, category: .tip) // 50% tip (unusually high)
        )

        let context = createContext(subtotalAmount: 50.00, totalAmount: 75.00)
        let validated = validator.validate(receipt, context: context)

        // Should have tip rate info
        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("Tip rate") })
    }

    // MARK: - Missing Items Validation Tests

    func testValidation_MissingTotal() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 12.99, category: .food)],
            total: nil
        )

        let context = createContext(subtotalAmount: 12.99, totalAmount: nil)
        let validated = validator.validate(receipt, context: context)

        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("No total") })
    }

    func testValidation_MissingTax() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 12.99, category: .food)],
            tax: nil,
            total: createItem(name: "Total", price: 12.99, category: .total)
        )

        let context = createContext(subtotalAmount: 12.99, totalAmount: 12.99)
        let validated = validator.validate(receipt, context: context)

        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("No tax") })
    }

    func testValidation_MissingFoodItems() {
        let receipt = createReceipt(
            foodItems: [],
            total: createItem(name: "Total", price: 10.00, category: .total)
        )

        let context = createContext(subtotalAmount: 0, totalAmount: 10.00)
        let validated = validator.validate(receipt, context: context)

        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("No food items") })
        XCTAssertEqual(validated.validationStatus, .invalid)
    }

    // MARK: - Low Confidence Validation Tests

    func testValidation_LowConfidenceItems() {
        let receipt = createReceipt(
            foodItems: [
                createItem(name: "Burger", price: 12.99, category: .food, confidence: 0.95),
                createItem(name: "Mystery Item", price: 5.00, category: .food, confidence: 0.60)
            ]
        )

        let context = createContext(subtotalAmount: 17.99, totalAmount: 20.00)
        let validated = validator.validate(receipt, context: context)

        XCTAssertTrue(validated.validationIssues.contains { $0.message.contains("need manual review") })
    }

    // MARK: - Validation Status Determination Tests

    func testValidationStatus_Valid() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 12.99, category: .food)],
            tax: createItem(name: "Tax", price: 1.30, category: .tax),
            total: createItem(name: "Total", price: 14.29, category: .total)
        )

        let context = createContext(subtotalAmount: 12.99, totalAmount: 14.29)
        let validated = validator.validate(receipt, context: context)

        XCTAssertEqual(validated.validationStatus, .valid)
    }

    func testValidationStatus_Warning() {
        let receipt = createReceipt(
            foodItems: [createItem(name: "Burger", price: 50.00, category: .food)],
            tax: createItem(name: "Tax", price: 10.00, category: .tax), // High tax rate = warning
            total: createItem(name: "Total", price: 60.00, category: .total)
        )

        let context = createContext(
            subtotalAmount: 50.00,
            totalAmount: 60.00,
            receiptType: .restaurant
        )
        let validated = validator.validate(receipt, context: context)

        // High tax rate should trigger warning status
        XCTAssertTrue([ValidationStatus.warning, ValidationStatus.needsReview].contains(validated.validationStatus))
    }

    func testValidationStatus_Invalid() {
        let receipt = createReceipt(
            foodItems: [], // No food items = error
            total: createItem(name: "Total", price: 10.00, category: .total)
        )

        let context = createContext(subtotalAmount: 0, totalAmount: 10.00)
        let validated = validator.validate(receipt, context: context)

        XCTAssertEqual(validated.validationStatus, .invalid)
    }

    // MARK: - Helper Methods

    private func createReceipt(
        foodItems: [ClassifiedReceiptItem] = [],
        tax: ClassifiedReceiptItem? = nil,
        tip: ClassifiedReceiptItem? = nil,
        gratuity: ClassifiedReceiptItem? = nil,
        subtotal: ClassifiedReceiptItem? = nil,
        total: ClassifiedReceiptItem? = nil,
        discounts: [ClassifiedReceiptItem] = [],
        otherCharges: [ClassifiedReceiptItem] = []
    ) -> ClassifiedReceipt {
        ClassifiedReceipt(
            foodItems: foodItems,
            tax: tax,
            tip: tip,
            gratuity: gratuity,
            subtotal: subtotal,
            total: total,
            discounts: discounts,
            otherCharges: otherCharges,
            unknownItems: [],
            totalConfidence: 0.85,
            validationStatus: .valid,
            validationIssues: []
        )
    }

    private func createItem(
        name: String,
        price: Double,
        category: ItemCategory,
        confidence: Double = 0.90
    ) -> ClassifiedReceiptItem {
        ClassifiedReceiptItem(
            id: UUID().uuidString,
            name: name,
            price: price,
            category: category,
            classificationConfidence: confidence,
            classificationMethod: .heuristic,
            originalText: name,
            position: 0,
            createdAt: Date(),
            updatedAt: Date(),
            correctedBy: nil,
            correctedAt: nil
        )
    }

    private func createContext(
        subtotalAmount: Double?,
        totalAmount: Double?,
        receiptType: ReceiptType = .restaurant
    ) -> ReceiptContext {
        ReceiptContext(
            totalAmount: totalAmount,
            subtotalAmount: subtotalAmount,
            itemCount: 5,
            receiptType: receiptType,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )
    }
}
