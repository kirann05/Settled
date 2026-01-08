//
//  IntegrationTests.swift
//  SettledTests
//
//  Created by Claude on 2025-10-26.
//

import XCTest
@testable import Settled

final class IntegrationTests: XCTestCase {

    var classifier: ReceiptClassifier!

    override func setUp() {
        super.setUp()
        classifier = ReceiptClassifier(config: .default)
    }

    // MARK: - Full Pipeline Integration Tests

    func testFullPipeline_SimpleRestaurantReceipt() async {
        // Simulate receipt items from OCR
        let items = [
            ReceiptItem(name: "Burger", price: 12.99),
            ReceiptItem(name: "Fries", price: 4.99),
            ReceiptItem(name: "Soda", price: 2.50),
            ReceiptItem(name: "Subtotal", price: 20.48),
            ReceiptItem(name: "Tax", price: 1.64),
            ReceiptItem(name: "Tip", price: 4.00),
            ReceiptItem(name: "Total", price: 26.12)
        ]

        let context = ReceiptContext(
            totalAmount: 26.12,
            subtotalAmount: 20.48,
            itemCount: items.count,
            receiptType: .restaurant,
            detectedLanguage: "en",
            merchantName: "Test Restaurant",
            date: Date()
        )

        let result = await classifier.classify(items, context: context)

        // Verify food items
        XCTAssertEqual(result.foodItems.count, 3)
        XCTAssertTrue(result.foodItems.contains { $0.name == "Burger" })
        XCTAssertTrue(result.foodItems.contains { $0.name == "Fries" })
        XCTAssertTrue(result.foodItems.contains { $0.name == "Soda" })

        // Verify tax
        XCTAssertNotNil(result.tax)
        XCTAssertEqual(result.tax?.price, 1.64)

        // Verify tip
        XCTAssertNotNil(result.tip)
        XCTAssertEqual(result.tip?.price, 4.00)

        // Verify subtotal
        XCTAssertNotNil(result.subtotal)
        XCTAssertEqual(result.subtotal?.price, 20.48)

        // Verify total
        XCTAssertNotNil(result.total)
        XCTAssertEqual(result.total?.price, 26.12)

        // Verify validation
        XCTAssertEqual(result.validationStatus, .valid)
        XCTAssertTrue(result.validationIssues.isEmpty)

        // Verify confidence
        XCTAssertGreaterThan(result.totalConfidence, 0.7)
    }

    func testFullPipeline_ReceiptWithGratuity() async {
        let items = [
            ReceiptItem(name: "1 Pasta", price: 18.00),
            ReceiptItem(name: "1 Pizza", price: 22.00),
            ReceiptItem(name: "2 Drinks", price: 8.00),
            ReceiptItem(name: "Subtotal", price: 48.00),
            ReceiptItem(name: "Tax", price: 3.84),
            ReceiptItem(name: "Large Party Gratuity (20%)", price: 9.60),
            ReceiptItem(name: "Total", price: 61.44)
        ]

        let context = ReceiptContext(
            totalAmount: 61.44,
            subtotalAmount: 48.00,
            itemCount: items.count,
            receiptType: .restaurant,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        // Verify food items (3 items with quantities)
        XCTAssertEqual(result.foodItems.count, 3)

        // Verify gratuity (not tip!)
        XCTAssertNotNil(result.gratuity)
        XCTAssertEqual(result.gratuity?.price, 9.60)
        XCTAssertNil(result.tip) // Should be nil, not tip

        // Verify validation
        XCTAssertEqual(result.validationStatus, .valid)
    }

    func testFullPipeline_ReceiptWithDiscounts() async {
        let items = [
            ReceiptItem(name: "Burger", price: 15.00),
            ReceiptItem(name: "Fries", price: 5.00),
            ReceiptItem(name: "Coupon -10%", price: -2.00),
            ReceiptItem(name: "Subtotal", price: 18.00),
            ReceiptItem(name: "Tax", price: 1.44),
            ReceiptItem(name: "Total", price: 19.44)
        ]

        let context = ReceiptContext(
            totalAmount: 19.44,
            subtotalAmount: 18.00,
            itemCount: items.count,
            receiptType: .restaurant,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        // Verify discount detected
        XCTAssertEqual(result.discounts.count, 1)
        XCTAssertEqual(result.discounts.first?.price, -2.00)

        // Verify food items
        XCTAssertEqual(result.foodItems.count, 2)
    }

    func testFullPipeline_ReceiptWithServiceCharge() async {
        let items = [
            ReceiptItem(name: "Pizza", price: 20.00),
            ReceiptItem(name: "Delivery Fee", price: 3.50),
            ReceiptItem(name: "Service Charge", price: 1.00),
            ReceiptItem(name: "Tax", price: 1.96),
            ReceiptItem(name: "Total", price: 26.46)
        ]

        let context = ReceiptContext(
            totalAmount: 26.46,
            subtotalAmount: 20.00,
            itemCount: items.count,
            receiptType: .delivery,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        // Verify other charges
        XCTAssertEqual(result.otherCharges.count, 2)
        XCTAssertTrue(result.otherCharges.contains { $0.name == "Delivery Fee" })
        XCTAssertTrue(result.otherCharges.contains { $0.name == "Service Charge" })

        // Verify food item
        XCTAssertEqual(result.foodItems.count, 1)
        XCTAssertEqual(result.foodItems.first?.name, "Pizza")
    }

    func testFullPipeline_GroceryReceipt() async {
        let items = [
            ReceiptItem(name: "Milk", price: 4.99),
            ReceiptItem(name: "Bread", price: 3.50),
            ReceiptItem(name: "Eggs", price: 5.99),
            ReceiptItem(name: "Tax", price: 0.00), // Some grocery items are tax-exempt
            ReceiptItem(name: "Total", price: 14.48)
        ]

        let context = ReceiptContext(
            totalAmount: 14.48,
            subtotalAmount: 14.48,
            itemCount: items.count,
            receiptType: .grocery,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        // Verify food items
        XCTAssertEqual(result.foodItems.count, 3)

        // Verify no tip (grocery doesn't expect tip)
        XCTAssertNil(result.tip)

        // Verify tax (even if $0)
        XCTAssertNotNil(result.tax)
        XCTAssertEqual(result.tax?.price, 0.00)

        // Verify total
        XCTAssertNotNil(result.total)
    }

    func testFullPipeline_MultiLanguageReceipt() async {
        let items = [
            ReceiptItem(name: "Croissant", price: 3.50),
            ReceiptItem(name: "Café", price: 2.50),
            ReceiptItem(name: "Sous-total", price: 6.00),
            ReceiptItem(name: "TVA (20%)", price: 1.20), // French VAT
            ReceiptItem(name: "Total", price: 7.20)
        ]

        let context = ReceiptContext(
            totalAmount: 7.20,
            subtotalAmount: 6.00,
            itemCount: items.count,
            receiptType: .restaurant,
            detectedLanguage: "fr",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        // Verify tax detected (TVA is French for VAT/tax)
        XCTAssertNotNil(result.tax)
        XCTAssertEqual(result.tax?.name, "TVA (20%)")

        // Verify subtotal
        XCTAssertNotNil(result.subtotal)

        // Verify food items
        XCTAssertEqual(result.foodItems.count, 2)
    }

    // MARK: - Performance Tests

    func testPerformance_ClassificationSpeed() {
        let items = createLargeReceipt(itemCount: 50)
        let context = ReceiptContext(
            totalAmount: 100.00,
            subtotalAmount: 80.00,
            itemCount: items.count,
            receiptType: .restaurant,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        measure {
            let expectation = XCTestExpectation(description: "Classification complete")

            Task {
                _ = await classifier.classify(items, context: context)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Edge Cases

    func testEdgeCase_EmptyReceipt() async {
        let items: [ReceiptItem] = []
        let context = ReceiptContext(
            totalAmount: nil,
            subtotalAmount: nil,
            itemCount: 0,
            receiptType: .unknown,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        XCTAssertEqual(result.validationStatus, .invalid)
        XCTAssertTrue(result.validationIssues.contains { $0.message.contains("No food items") })
    }

    func testEdgeCase_OnlyTotal() async {
        let items = [
            ReceiptItem(name: "Total", price: 50.00)
        ]

        let context = ReceiptContext(
            totalAmount: 50.00,
            subtotalAmount: nil,
            itemCount: items.count,
            receiptType: .restaurant,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        XCTAssertNotNil(result.total)
        XCTAssertEqual(result.foodItems.count, 0)
        XCTAssertNotEqual(result.validationStatus, .valid) // Should warn about no food items
    }

    func testEdgeCase_AmbiguousItems() async {
        let items = [
            ReceiptItem(name: "Item 1", price: 10.00),
            ReceiptItem(name: "Item 2", price: 15.00),
            ReceiptItem(name: "Item 3", price: 20.00),
            ReceiptItem(name: "45.00", price: 45.00) // Ambiguous total
        ]

        let context = ReceiptContext(
            totalAmount: 45.00,
            subtotalAmount: nil,
            itemCount: items.count,
            receiptType: .unknown,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )

        let result = await classifier.classify(items, context: context)

        // Should still classify something
        XCTAssertGreaterThan(result.foodItems.count + result.unknownItems.count, 0)
    }

    // MARK: - Helper Methods

    private func createLargeReceipt(itemCount: Int) -> [ReceiptItem] {
        var items: [ReceiptItem] = []

        for i in 1...itemCount {
            items.append(ReceiptItem(name: "Item \(i)", price: Double(i)))
        }

        items.append(ReceiptItem(name: "Tax", price: 10.00))
        items.append(ReceiptItem(name: "Total", price: Double(itemCount * (itemCount + 1) / 2 + 10)))

        return items
    }
}

extension ReceiptItem {
    init(name: String, price: Double) {
        self.name = name
        self.price = price
        self.confidence = .high
    }
}
