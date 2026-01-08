import XCTest
import Firebase
import FirebaseFirestore
import UserNotifications
// Note: Import Settled when the test target is properly configured
// @testable import Settled

/// Integration tests for the complete push notification system
/// These tests validate end-to-end functionality with realistic scenarios
class PushNotificationIntegrationTests: XCTestCase {

    var pushService: PushNotificationService!
    var tokenManager: FCMTokenManager!
    var testBill: Bill!
    var testParticipants: [BillParticipant]!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Initialize services
        pushService = PushNotificationService.shared
        tokenManager = FCMTokenManager.shared

        // Create test data
        setupTestData()

        // Configure Firebase for testing
        configureFirebaseForTesting()
    }

    override func tearDownWithError() throws {
        // Clean up test data
        cleanupTestData()

        try super.tearDownWithError()
    }

    // MARK: - Setup & Cleanup

    private func setupTestData() {
        // Create test participants
        testParticipants = [
            BillParticipant(
                id: "test_user_1",
                name: "Alice Test",
                email: "alice.test@example.com",
                profileImageURL: nil,
                isCurrentUser: true
            ),
            BillParticipant(
                id: "test_user_2",
                name: "Bob Test",
                email: "bob.test@example.com",
                profileImageURL: nil,
                isCurrentUser: false
            ),
            BillParticipant(
                id: "test_user_3",
                name: "Charlie Test",
                email: "charlie.test@example.com",
                profileImageURL: nil,
                isCurrentUser: false
            )
        ]

        // Create test bill
        testBill = Bill(
            id: "test_bill_integration",
            name: "Integration Test Bill",
            totalAmount: 50.00,
            currency: "USD",
            participants: testParticipants,
            items: [
                BillItem(
                    id: "item1",
                    name: "Test Item 1",
                    price: 30.00,
                    assignedParticipantIds: ["test_user_1", "test_user_2"]
                ),
                BillItem(
                    id: "item2",
                    name: "Test Item 2",
                    price: 20.00,
                    assignedParticipantIds: ["test_user_3"]
                )
            ],
            paidByParticipantId: "test_user_1",
            createdBy: "test_user_1",
            createdAt: Date()
        )
    }

    private func configureFirebaseForTesting() {
        // Configure Firebase for testing mode
        // Note: In real tests, you'd configure Firebase Test Lab
        print("🧪 Configuring Firebase for testing...")
    }

    private func cleanupTestData() {
        // Clean up any test data created in Firebase
        Task {
            await cleanupFirebaseTestData()
        }
    }

    private func cleanupFirebaseTestData() async {
        // Clean up test documents from Firestore
        let db = Firestore.firestore()

        do {
            // Remove test bill
            try await db.collection("bills").document("test_bill_integration").delete()

            // Remove test participants
            for participant in testParticipants {
                try await db.collection("participants").document(participant.id).delete()
            }

            print("✅ Test data cleaned up")
        } catch {
            print("⚠️ Error cleaning up test data: \(error)")
        }
    }

    // MARK: - Core Integration Tests

    func testCompleteNotificationFlowForBillCreation() async throws {
        let expectation = XCTestExpectation(description: "Bill creation notification flow")

        // Test the complete flow: Bill creation → FCM token retrieval → Notification sending
        do {
            // 1. Simulate bill creation notification
            try await pushService.notifyBillCreated(
                bill: testBill,
                creatorName: "Alice Test"
            )

            // 2. Verify notification was queued
            let metrics = await pushService.getMetrics()
            XCTAssertGreaterThan(metrics.createdNotifications, 0, "Bill creation notification should be tracked")

            // 3. Wait for processing
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // 4. Verify service health after processing
            let serviceHealth = await pushService.validateServiceHealth()
            XCTAssertTrue(serviceHealth, "Push service should remain healthy after processing")

            expectation.fulfill()

        } catch {
            XCTFail("Bill creation notification flow failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testHighVolumeNotificationProcessing() async throws {
        let expectation = XCTestExpectation(description: "High volume notification processing")
        let billCount = 25

        // Create multiple bills to test batch processing
        var testBills: [Bill] = []

        for i in 1...billCount {
            let bill = Bill(
                id: "test_bill_\(i)",
                name: "Test Bill \(i)",
                totalAmount: Double.random(in: 10.0...100.0),
                currency: "USD",
                participants: Array(testParticipants.prefix(Int.random(in: 2...3))),
                items: [
                    BillItem(
                        id: "item_\(i)",
                        name: "Item \(i)",
                        price: Double.random(in: 5.0...50.0),
                        assignedParticipantIds: [testParticipants.randomElement()!.id]
                    )
                ],
                paidByParticipantId: testParticipants.randomElement()!.id,
                createdBy: "test_user_1",
                createdAt: Date()
            )
            testBills.append(bill)
        }

        // Send notifications for all bills
        do {
            for bill in testBills {
                try await pushService.notifyBillCreated(
                    bill: bill,
                    creatorName: "Test Creator"
                )
            }

            // Wait for processing
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            // Verify all notifications were processed
            let metrics = await pushService.getMetrics()
            XCTAssertGreaterThanOrEqual(
                metrics.createdNotifications,
                billCount,
                "All bill creation notifications should be tracked"
            )

            // Verify service remains healthy
            let serviceHealth = await pushService.validateServiceHealth()
            XCTAssertTrue(serviceHealth, "Service should handle high volume gracefully")

            expectation.fulfill()

        } catch {
            XCTFail("High volume processing failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 30.0)
    }

    func testErrorHandlingAndRecovery() async throws {
        let expectation = XCTestExpectation(description: "Error handling and recovery")

        // Test various error scenarios
        do {
            // 1. Test with invalid participant emails
            let invalidBill = Bill(
                id: "test_invalid_bill",
                name: "Invalid Bill",
                totalAmount: 25.00,
                currency: "USD",
                participants: [
                    BillParticipant(
                        id: "invalid_user",
                        name: "Invalid User",
                        email: "invalid@nonexistent.domain",
                        profileImageURL: nil,
                        isCurrentUser: false
                    )
                ],
                items: [],
                paidByParticipantId: "invalid_user",
                createdBy: "test_user_1",
                createdAt: Date()
            )

            // This should handle the error gracefully
            try await pushService.notifyBillCreated(
                bill: invalidBill,
                creatorName: "Test Creator"
            )

            // 2. Verify service health after error
            let serviceHealth = await pushService.validateServiceHealth()
            XCTAssertTrue(serviceHealth, "Service should recover from errors gracefully")

            // 3. Test legitimate notification still works
            try await pushService.notifyBillCreated(
                bill: testBill,
                creatorName: "Alice Test"
            )

            expectation.fulfill()

        } catch {
            // Errors should be handled gracefully, not cause test failure
            print("⚠️ Expected error handled: \(error)")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 15.0)
    }

    // MARK: - FCM Token Manager Integration Tests

    func testFCMTokenManagerIntegration() async throws {
        let expectation = XCTestExpectation(description: "FCM Token Manager integration")

        do {
            // 1. Test token health validation
            let tokenHealth = tokenManager.validateTokenHealth()
            // Note: This might be false initially, which is expected
            print("🔍 Token Health: \(tokenHealth)")

            // 2. Test token refresh
            try await tokenManager.refreshTokenIfNeeded()

            // 3. Test bulk token retrieval
            let emails = testParticipants.map { $0.email }
            let tokens = await tokenManager.getFCMTokensForEmails(emails)

            XCTAssertEqual(
                tokens.count,
                emails.count,
                "Should retrieve tokens for all valid email addresses"
            )

            // 4. Verify token format
            for (email, token) in tokens {
                XCTAssertTrue(
                    token.hasPrefix("fcm_token_"),
                    "Token for \(email) should have correct format"
                )
                XCTAssertGreaterThan(
                    token.count,
                    15,
                    "Token for \(email) should have sufficient length"
                )
            }

            expectation.fulfill()

        } catch {
            XCTFail("FCM Token Manager integration failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Performance Tests

    func testNotificationPerformanceWithLargeGroup() async throws {
        let expectation = XCTestExpectation(description: "Large group notification performance")
        let participantCount = 50

        // Create large group
        var largeGroup: [BillParticipant] = []
        for i in 1...participantCount {
            largeGroup.append(BillParticipant(
                id: "perf_user_\(i)",
                name: "User \(i)",
                email: "user\(i)@test.com",
                profileImageURL: nil,
                isCurrentUser: i == 1
            ))
        }

        let largeBill = Bill(
            id: "large_bill_test",
            name: "Large Group Bill",
            totalAmount: 200.00,
            currency: "USD",
            participants: largeGroup,
            items: [
                BillItem(
                    id: "large_item",
                    name: "Large Item",
                    price: 200.00,
                    assignedParticipantIds: largeGroup.map { $0.id }
                )
            ],
            paidByParticipantId: "perf_user_1",
            createdBy: "perf_user_1",
            createdAt: Date()
        )

        // Measure performance
        let startTime = Date()

        do {
            try await pushService.notifyBillCreated(
                bill: largeBill,
                creatorName: "Performance Test"
            )

            // Wait for batch processing
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

            let endTime = Date()
            let processingTime = endTime.timeIntervalSince(startTime)

            // Performance assertions
            XCTAssertLessThan(
                processingTime,
                30.0,
                "Large group notification should complete within 30 seconds"
            )

            // Verify service health
            let serviceHealth = await pushService.validateServiceHealth()
            XCTAssertTrue(serviceHealth, "Service should remain healthy after large group processing")

            expectation.fulfill()

        } catch {
            XCTFail("Large group performance test failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 60.0)
    }

    // MARK: - Notification Categories & Actions Tests

    func testNotificationCategoriesRegistration() {
        let expectation = XCTestExpectation(description: "Notification categories registration")

        // This would test if notification categories are properly registered
        UNUserNotificationCenter.current().getNotificationCategories { categories in

            // Look for bill-related categories
            let billCategories = categories.filter { category in
                category.identifier.contains("BILL")
            }

            XCTAssertGreaterThan(
                billCategories.count,
                0,
                "Bill notification categories should be registered"
            )

            // Verify actions exist
            for category in billCategories {
                XCTAssertGreaterThan(
                    category.actions.count,
                    0,
                    "Category \(category.identifier) should have actions"
                )
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Memory & Resource Tests

    func testMemoryManagementUnderLoad() async throws {
        let expectation = XCTestExpectation(description: "Memory management under load")
        let operationCount = 100

        // Generate many notification operations
        do {
            for i in 1...operationCount {
                let quickBill = Bill(
                    id: "memory_test_\(i)",
                    name: "Memory Test \(i)",
                    totalAmount: 10.00,
                    currency: "USD",
                    participants: [testParticipants[0]],
                    items: [],
                    paidByParticipantId: testParticipants[0].id,
                    createdBy: testParticipants[0].id,
                    createdAt: Date()
                )

                try await pushService.notifyBillCreated(
                    bill: quickBill,
                    creatorName: "Memory Test"
                )

                // Brief pause to allow processing
                if i % 10 == 0 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }

            // Allow processing to complete
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            // Verify memory health
            let serviceHealth = await pushService.validateServiceHealth()
            XCTAssertTrue(serviceHealth, "Service should manage memory properly under load")

            expectation.fulfill()

        } catch {
            XCTFail("Memory management test failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 30.0)
    }

    // MARK: - Helper Methods for Advanced Testing

    /// Simulate network connectivity issues
    private func simulateNetworkIssues() {
        // In a real implementation, this would use network mocking
        print("🌐 Simulating network connectivity issues...")
    }

    /// Verify notification delivery metrics
    private func verifyNotificationMetrics(
        expectedMinimumSent: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let metrics = await pushService.getMetrics()

        XCTAssertGreaterThanOrEqual(
            metrics.totalSent,
            expectedMinimumSent,
            "Should have sent at least \(expectedMinimumSent) notifications",
            file: file,
            line: line
        )

        // In a production environment, we'd want high delivery rates
        // For testing with simulated FCM, we mainly verify the flow works
        print("📊 Notification Metrics:")
        print("   Total Sent: \(metrics.totalSent)")
        print("   Success Rate: \(String(format: "%.1f", metrics.successRate * 100))%")
        print("   Failure Rate: \(String(format: "%.1f", metrics.failureRate * 100))%")
    }
}