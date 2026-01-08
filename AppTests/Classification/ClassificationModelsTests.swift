//
//  ClassificationModelsTests.swift
//  SettledTests
//
//  Created by Claude on 2025-10-26.
//

import XCTest
@testable import Settled

final class ClassificationModelsTests: XCTestCase {

    // MARK: - ItemCategory Tests

    func testItemCategoryDisplayNames() {
        XCTAssertEqual(ItemCategory.food.displayName, "Food")
        XCTAssertEqual(ItemCategory.tax.displayName, "Tax")
        XCTAssertEqual(ItemCategory.tip.displayName, "Tip")
        XCTAssertEqual(ItemCategory.gratuity.displayName, "Gratuity")
        XCTAssertEqual(ItemCategory.subtotal.displayName, "Subtotal")
        XCTAssertEqual(ItemCategory.total.displayName, "Total")
        XCTAssertEqual(ItemCategory.discount.displayName, "Discount")
        XCTAssertEqual(ItemCategory.serviceCharge.displayName, "Service Charge")
        XCTAssertEqual(ItemCategory.deliveryFee.displayName, "Delivery Fee")
        XCTAssertEqual(ItemCategory.unknown.displayName, "Unknown")
    }

    func testItemCategoryAdditionalChargeProperty() {
        XCTAssertFalse(ItemCategory.food.isAdditionalCharge)
        XCTAssertTrue(ItemCategory.tax.isAdditionalCharge)
        XCTAssertTrue(ItemCategory.tip.isAdditionalCharge)
        XCTAssertTrue(ItemCategory.gratuity.isAdditionalCharge)
        XCTAssertFalse(ItemCategory.subtotal.isAdditionalCharge)
        XCTAssertFalse(ItemCategory.total.isAdditionalCharge)
        XCTAssertFalse(ItemCategory.discount.isAdditionalCharge)
        XCTAssertTrue(ItemCategory.serviceCharge.isAdditionalCharge)
        XCTAssertTrue(ItemCategory.deliveryFee.isAdditionalCharge)
        XCTAssertFalse(ItemCategory.unknown.isAdditionalCharge)
    }

    // MARK: - ClassifiedReceiptItem Tests

    func testClassifiedReceiptItemCreation() {
        let item = ClassifiedReceiptItem(
            id: "test-1",
            name: "Burger",
            price: 12.99,
            category: .food,
            classificationConfidence: 0.95,
            classificationMethod: .heuristic,
            originalText: "Burger",
            position: 0,
            createdAt: Date(),
            updatedAt: Date(),
            correctedBy: nil,
            correctedAt: nil
        )

        XCTAssertEqual(item.name, "Burger")
        XCTAssertEqual(item.price, 12.99)
        XCTAssertEqual(item.category, .food)
        XCTAssertEqual(item.classificationConfidence, 0.95)
        XCTAssertEqual(item.classificationMethod, .heuristic)
        XCTAssertNil(item.correctedBy)
    }

    func testClassifiedReceiptItemCorrection() {
        let originalItem = ClassifiedReceiptItem(
            id: "test-1",
            name: "Tax",
            price: 1.30,
            category: .unknown,
            classificationConfidence: 0.50,
            classificationMethod: .geometric,
            originalText: "Tax",
            position: 1,
            createdAt: Date(),
            updatedAt: Date(),
            correctedBy: nil,
            correctedAt: nil
        )

        let correctedItem = originalItem.corrected(to: .tax, by: "user123")

        XCTAssertEqual(correctedItem.category, .tax)
        XCTAssertEqual(correctedItem.correctedBy, "user123")
        XCTAssertNotNil(correctedItem.correctedAt)
        XCTAssertEqual(correctedItem.classificationMethod, .manual)
        XCTAssertEqual(correctedItem.classificationConfidence, 1.0)
    }

    func testClassifiedReceiptItemNeedsReview() {
        let highConfidenceItem = ClassifiedReceiptItem(
            id: "1",
            name: "Item",
            price: 10.0,
            category: .food,
            classificationConfidence: 0.90,
            classificationMethod: .heuristic,
            originalText: "Item",
            position: 0,
            createdAt: Date(),
            updatedAt: Date(),
            correctedBy: nil,
            correctedAt: nil
        )

        let lowConfidenceItem = ClassifiedReceiptItem(
            id: "2",
            name: "Item",
            price: 10.0,
            category: .food,
            classificationConfidence: 0.60,
            classificationMethod: .heuristic,
            originalText: "Item",
            position: 0,
            createdAt: Date(),
            updatedAt: Date(),
            correctedBy: nil,
            correctedAt: nil
        )

        XCTAssertFalse(highConfidenceItem.needsReview)
        XCTAssertTrue(lowConfidenceItem.needsReview)
    }

    func testConfidenceLevel() {
        let highItem = ClassifiedReceiptItem(
            id: "1", name: "Item", price: 10.0, category: .food,
            classificationConfidence: 0.95, classificationMethod: .heuristic,
            originalText: "Item", position: 0, createdAt: Date(),
            updatedAt: Date(), correctedBy: nil, correctedAt: nil
        )

        let mediumItem = ClassifiedReceiptItem(
            id: "2", name: "Item", price: 10.0, category: .food,
            classificationConfidence: 0.75, classificationMethod: .heuristic,
            originalText: "Item", position: 0, createdAt: Date(),
            updatedAt: Date(), correctedBy: nil, correctedAt: nil
        )

        let lowItem = ClassifiedReceiptItem(
            id: "3", name: "Item", price: 10.0, category: .food,
            classificationConfidence: 0.50, classificationMethod: .heuristic,
            originalText: "Item", position: 0, createdAt: Date(),
            updatedAt: Date(), correctedBy: nil, correctedAt: nil
        )

        XCTAssertEqual(highItem.confidenceLevel, .high)
        XCTAssertEqual(mediumItem.confidenceLevel, .medium)
        XCTAssertEqual(lowItem.confidenceLevel, .low)
    }

    // MARK: - ClassifiedReceipt Tests

    func testClassifiedReceiptFoodItemsSum() {
        let receipt = ClassifiedReceipt(
            foodItems: [
                createTestItem(name: "Burger", price: 12.99, category: .food),
                createTestItem(name: "Fries", price: 4.99, category: .food),
                createTestItem(name: "Soda", price: 2.50, category: .food)
            ],
            tax: nil,
            tip: nil,
            gratuity: nil,
            subtotal: nil,
            total: nil,
            discounts: [],
            otherCharges: [],
            unknownItems: [],
            totalConfidence: 0.90,
            validationStatus: .valid,
            validationIssues: []
        )

        let sum = receipt.foodItemsSum()
        XCTAssertEqual(sum, 20.48, accuracy: 0.01)
    }

    func testClassifiedReceiptTotalCharges() {
        let receipt = ClassifiedReceipt(
            foodItems: [
                createTestItem(name: "Burger", price: 12.99, category: .food)
            ],
            tax: createTestItem(name: "Tax", price: 1.30, category: .tax),
            tip: createTestItem(name: "Tip", price: 2.00, category: .tip),
            gratuity: nil,
            subtotal: nil,
            total: nil,
            discounts: [],
            otherCharges: [],
            unknownItems: [],
            totalConfidence: 0.90,
            validationStatus: .valid,
            validationIssues: []
        )

        let total = receipt.totalCharges()
        XCTAssertEqual(total, 16.29, accuracy: 0.01)
    }

    func testClassifiedReceiptSumMatchesTotal() {
        let receipt = ClassifiedReceipt(
            foodItems: [
                createTestItem(name: "Burger", price: 12.99, category: .food)
            ],
            tax: createTestItem(name: "Tax", price: 1.30, category: .tax),
            tip: nil,
            gratuity: nil,
            subtotal: nil,
            total: createTestItem(name: "Total", price: 14.29, category: .total),
            discounts: [],
            otherCharges: [],
            unknownItems: [],
            totalConfidence: 0.90,
            validationStatus: .valid,
            validationIssues: []
        )

        XCTAssertTrue(receipt.sumMatchesTotal(tolerance: 0.01))
    }

    func testClassifiedReceiptAllItemsSorted() {
        let receipt = ClassifiedReceipt(
            foodItems: [
                createTestItem(name: "Item 2", price: 10.0, category: .food, position: 2)
            ],
            tax: createTestItem(name: "Tax", price: 1.0, category: .tax, position: 3),
            tip: nil,
            gratuity: nil,
            subtotal: createTestItem(name: "Subtotal", price: 10.0, category: .subtotal, position: 1),
            total: createTestItem(name: "Total", price: 11.0, category: .total, position: 4),
            discounts: [],
            otherCharges: [],
            unknownItems: [
                createTestItem(name: "Unknown", price: 5.0, category: .unknown, position: 0)
            ],
            totalConfidence: 0.80,
            validationStatus: .valid,
            validationIssues: []
        )

        let allItems = receipt.allItems
        XCTAssertEqual(allItems.count, 5)
        XCTAssertEqual(allItems[0].name, "Unknown")
        XCTAssertEqual(allItems[1].name, "Subtotal")
        XCTAssertEqual(allItems[2].name, "Item 2")
        XCTAssertEqual(allItems[3].name, "Tax")
        XCTAssertEqual(allItems[4].name, "Total")
    }

    // MARK: - ReceiptContext Tests

    func testReceiptTypeExpectations() {
        XCTAssertTrue(ReceiptType.restaurant.expectsTip)
        XCTAssertFalse(ReceiptType.grocery.expectsTip)
        XCTAssertFalse(ReceiptType.retail.expectsTip)
        XCTAssertTrue(ReceiptType.delivery.expectsTip)

        XCTAssertFalse(ReceiptType.restaurant.expectsServiceCharge)
        XCTAssertFalse(ReceiptType.grocery.expectsServiceCharge)
        XCTAssertTrue(ReceiptType.delivery.expectsServiceCharge)
    }

    func testReceiptTypeTaxRanges() {
        XCTAssertEqual(ReceiptType.restaurant.typicalTaxRange, 0.05...0.12)
        XCTAssertEqual(ReceiptType.grocery.typicalTaxRange, 0.00...0.10)
        XCTAssertEqual(ReceiptType.retail.typicalTaxRange, 0.06...0.10)
        XCTAssertEqual(ReceiptType.delivery.typicalTaxRange, 0.05...0.12)
        XCTAssertEqual(ReceiptType.unknown.typicalTaxRange, 0.05...0.15)
    }

    // MARK: - Helper Methods

    private func createTestItem(
        name: String,
        price: Double,
        category: ItemCategory,
        position: Int = 0,
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
            position: position,
            createdAt: Date(),
            updatedAt: Date(),
            correctedBy: nil,
            correctedAt: nil
        )
    }
}
