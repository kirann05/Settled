//
//  ClassificationStrategyTests.swift
//  SettledTests
//
//  Created by Claude on 2025-10-26.
//

import XCTest
@testable import Settled

final class ClassificationStrategyTests: XCTestCase {

    // MARK: - Geometric Strategy Tests

    func testGeometricStrategy_LastLineIsTotal() async {
        let strategy = GeometricClassificationStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)
        let item = ReceiptItem(name: "Total", price: 50.00)

        let result = await strategy.classify(item, at: 9, context: context)

        XCTAssertEqual(result.category, .total)
        XCTAssertGreaterThan(result.confidence, 0.9)
        XCTAssertEqual(result.method, .geometric)
    }

    func testGeometricStrategy_SecondToLastIsTaxOrTip() async {
        let strategy = GeometricClassificationStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)

        // Test tax
        let taxItem = ReceiptItem(name: "Tax", price: 4.00)
        let taxResult = await strategy.classify(taxItem, at: 8, context: context)
        XCTAssertEqual(taxResult.category, .tax)

        // Test tip
        let tipItem = ReceiptItem(name: "Tip", price: 8.00)
        let tipResult = await strategy.classify(tipItem, at: 8, context: context)
        XCTAssertEqual(tipResult.category, .tip)
    }

    func testGeometricStrategy_MiddleZoneIsFoodItem() async {
        let strategy = GeometricClassificationStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)
        let item = ReceiptItem(name: "Burger", price: 12.99)

        let result = await strategy.classify(item, at: 4, context: context)

        XCTAssertEqual(result.category, .food)
        XCTAssertGreaterThan(result.confidence, 0.6)
    }

    // MARK: - Pattern Heuristic Strategy Tests

    func testPatternStrategy_PercentageDetection() async {
        let strategy = PatternHeuristicStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)

        // Gratuity with percentage
        let gratuityItem = ReceiptItem(name: "Gratuity (20%)", price: 10.00)
        let gratuityResult = await strategy.classify(gratuityItem, at: 5, context: context)
        XCTAssertEqual(gratuityResult.category, .gratuity)
        XCTAssertGreaterThan(gratuityResult.confidence, 0.8)

        // Tax with percentage
        let taxItem = ReceiptItem(name: "Tax (8.5%)", price: 4.25)
        let taxResult = await strategy.classify(taxItem, at: 5, context: context)
        XCTAssertEqual(taxResult.category, .tax)
    }

    func testPatternStrategy_QuantityDetection() async {
        let strategy = PatternHeuristicStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)
        let item = ReceiptItem(name: "2 Burgers", price: 24.00)

        let result = await strategy.classify(item, at: 2, context: context)

        XCTAssertEqual(result.category, .food)
        XCTAssertGreaterThan(result.confidence, 0.85)
    }

    func testPatternStrategy_NegativePriceIsDiscount() async {
        let strategy = PatternHeuristicStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)
        let item = ReceiptItem(name: "Coupon", price: -5.00)

        let result = await strategy.classify(item, at: 3, context: context)

        XCTAssertEqual(result.category, .discount)
        XCTAssertGreaterThan(result.confidence, 0.8)
    }

    func testPatternStrategy_MultiLanguageKeywords() async {
        let strategy = PatternHeuristicStrategy()
        let context = createContext(itemCount: 10, totalAmount: 50.00)

        // English
        let englishTax = ReceiptItem(name: "Tax", price: 5.00)
        let englishResult = await strategy.classify(englishTax, at: 5, context: context)
        XCTAssertEqual(englishResult.category, .tax)

        // French
        let frenchTax = ReceiptItem(name: "TVA", price: 5.00)
        let frenchResult = await strategy.classify(frenchTax, at: 5, context: context)
        XCTAssertEqual(frenchResult.category, .tax)

        // Spanish
        let spanishTax = ReceiptItem(name: "IVA", price: 5.00)
        let spanishResult = await strategy.classify(spanishTax, at: 5, context: context)
        XCTAssertEqual(spanishResult.category, .tax)
    }

    // MARK: - Price Relationship Strategy Tests

    func testPriceRelationshipStrategy_TaxRateValidation() async {
        let strategy = PriceRelationshipStrategy()
        let context = createContext(
            itemCount: 5,
            subtotalAmount: 50.00,
            totalAmount: 54.00,
            receiptType: .restaurant
        )

        // 8% tax rate (within restaurant range 5-12%)
        let taxItem = ReceiptItem(name: "Tax", price: 4.00)
        let result = await strategy.classify(taxItem, at: 3, context: context)

        XCTAssertEqual(result.category, .tax)
        XCTAssertGreaterThan(result.confidence, 0.7)
    }

    func testPriceRelationshipStrategy_TipRateValidation() async {
        let strategy = PriceRelationshipStrategy()
        let context = createContext(
            itemCount: 5,
            subtotalAmount: 50.00,
            totalAmount: 60.00
        )

        // 20% tip (within typical range 10-30%)
        let tipItem = ReceiptItem(name: "Tip", price: 10.00)
        let result = await strategy.classify(tipItem, at: 3, context: context)

        XCTAssertEqual(result.category, .tip)
        XCTAssertGreaterThan(result.confidence, 0.7)
    }

    func testPriceRelationshipStrategy_TotalSumValidation() async {
        let strategy = PriceRelationshipStrategy()
        let context = createContext(
            itemCount: 5,
            subtotalAmount: 50.00,
            totalAmount: 60.00
        )

        let totalItem = ReceiptItem(name: "Total", price: 60.00)
        let result = await strategy.classify(totalItem, at: 4, context: context)

        XCTAssertEqual(result.category, .total)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testPriceRelationshipStrategy_SubtotalSumValidation() async {
        let strategy = PriceRelationshipStrategy()
        let context = createContext(
            itemCount: 5,
            subtotalAmount: 50.00,
            totalAmount: 60.00
        )

        let subtotalItem = ReceiptItem(name: "Subtotal", price: 50.00)
        let result = await strategy.classify(subtotalItem, at: 2, context: context)

        XCTAssertEqual(result.category, .subtotal)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    // MARK: - Strategy Chain Tests

    func testStrategyChain_StopsAtHighConfidence() async {
        let geometricStrategy = GeometricClassificationStrategy()
        let patternStrategy = PatternHeuristicStrategy()

        let chain = ClassificationStrategyChain(
            strategies: [geometricStrategy, patternStrategy],
            config: .default
        )

        let context = createContext(itemCount: 10, totalAmount: 50.00)
        let item = ReceiptItem(name: "Total", price: 50.00)

        // Should stop at geometric strategy (last line = high confidence total)
        let result = await chain.classify(item, at: 9, context: context)

        XCTAssertEqual(result.category, .total)
        XCTAssertEqual(result.method, .geometric)
        XCTAssertGreaterThan(result.confidence, 0.8)
    }

    func testStrategyChain_FallsThrough() async {
        let geometricStrategy = GeometricClassificationStrategy()
        let patternStrategy = PatternHeuristicStrategy()

        let chain = ClassificationStrategyChain(
            strategies: [geometricStrategy, patternStrategy],
            config: .default
        )

        let context = createContext(itemCount: 10, totalAmount: 50.00)
        // Ambiguous item in middle zone - should fall through to pattern strategy
        let item = ReceiptItem(name: "2 Burgers", price: 20.00)

        let result = await chain.classify(item, at: 4, context: context)

        // Should be classified by pattern strategy (quantity detection)
        XCTAssertEqual(result.category, .food)
    }

    // MARK: - Helper Methods

    private func createContext(
        itemCount: Int,
        subtotalAmount: Double? = nil,
        totalAmount: Double? = nil,
        receiptType: ReceiptType = .restaurant
    ) -> ReceiptContext {
        ReceiptContext(
            totalAmount: totalAmount,
            subtotalAmount: subtotalAmount,
            itemCount: itemCount,
            receiptType: receiptType,
            detectedLanguage: "en",
            merchantName: nil,
            date: nil
        )
    }
}

// MARK: - ReceiptItem Extensions for Testing

extension ReceiptItem {
    init(name: String, price: Double) {
        self.name = name
        self.price = price
        self.confidence = .high
    }
}
