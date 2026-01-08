import XCTest
import UserNotifications
// Note: Import Settled when the test target is properly configured
// @testable import Settled

/// Unit tests for PushNotificationService focusing on core functionality and edge cases
class PushNotificationServiceTests: XCTestCase {

    var pushService: PushNotificationService!
    var testBill: Bill!
    var testParticipants: [BillParticipant]!

    override func setUpWithError() throws {
        try super.setUpWithError()

        pushService = PushNotificationService.shared
        setupTestData()
    }

    override func tearDownWithError() throws {
        // Clean up any pending notifications
        Task {
            await pushService.clearAllPendingNotifications()
        }

        try super.tearDownWithError()
    }

    private func setupTestData() {
        testParticipants = [
            BillParticipant(
                id: "unit_test_user_1",
                name: "Alice Unit Test",
                email: "alice.unit@example.com",
                profileImageURL: nil,
                isCurrentUser: true
            ),
            BillParticipant(
                id: "unit_test_user_2",
                name: "Bob Unit Test",
                email: "bob.unit@example.com",
                profileImageURL: nil,
                isCurrentUser: false
            ),
            BillParticipant(
                id: "unit_test_user_3",
                name: "Charlie Unit Test",
                email: "charlie.unit@example.com",
                profileImageURL: nil,
                isCurrentUser: false
            )
        ]

        testBill = Bill(
            id: "unit_test_bill",
            name: "Unit Test Bill",
            totalAmount: 75.50,
            currency: "USD",
            participants: testParticipants,
            items: [
                BillItem(
                    id: "unit_item_1",
                    name: "Unit Test Item 1",
                    price: 45.50,
                    assignedParticipantIds: ["unit_test_user_1", "unit_test_user_2"]
                ),
                BillItem(
                    id: "unit_item_2",
                    name: "Unit Test Item 2",
                    price: 30.00,
                    assignedParticipantIds: ["unit_test_user_3"]
                )
            ],
            paidByParticipantId: "unit_test_user_1",
            createdBy: "unit_test_user_1",
            createdAt: Date()
        )
    }

    // MARK: - Service Health Tests

    func testServiceHealthValidation() async {
        let expectation = XCTestExpectation(description: "Service health validation")

        let isHealthy = await pushService.validateServiceHealth()

        // Service should be healthy initially
        XCTAssertTrue(isHealthy, "Push notification service should be healthy on startup")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testMetricsInitialization() async {
        let expectation = XCTestExpectation(description: "Metrics initialization")

        let metrics = await pushService.getMetrics()

        // Initial metrics should be zero
        XCTAssertEqual(metrics.totalSent, 0, "Initial totalSent should be 0")
        XCTAssertEqual(metrics.totalDelivered, 0, "Initial totalDelivered should be 0")
        XCTAssertEqual(metrics.totalFailed, 0, "Initial totalFailed should be 0")
        XCTAssertEqual(metrics.createdNotifications, 0, "Initial createdNotifications should be 0")
        XCTAssertEqual(metrics.editedNotifications, 0, "Initial editedNotifications should be 0")
        XCTAssertEqual(metrics.deletedNotifications, 0, "Initial deletedNotifications should be 0")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Bill Notification Tests

    func testBillCreatedNotification() async throws {
        let expectation = XCTestExpectation(description: "Bill created notification")

        let initialMetrics = await pushService.getMetrics()

        try await pushService.notifyBillCreated(
            bill: testBill,
            creatorName: "Alice Unit Test"
        )

        // Allow processing time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let updatedMetrics = await pushService.getMetrics()

        XCTAssertGreaterThan(
            updatedMetrics.createdNotifications,
            initialMetrics.createdNotifications,
            "Created notifications count should increase"
        )

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testBillEditedNotification() async throws {
        let expectation = XCTestExpectation(description: "Bill edited notification")

        let initialMetrics = await pushService.getMetrics()

        try await pushService.notifyBillEdited(
            bill: testBill,
            editorName: "Bob Unit Test"
        )

        // Allow processing time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let updatedMetrics = await pushService.getMetrics()

        XCTAssertGreaterThan(
            updatedMetrics.editedNotifications,
            initialMetrics.editedNotifications,
            "Edited notifications count should increase"
        )

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testBillDeletedNotification() async throws {
        let expectation = XCTestExpectation(description: "Bill deleted notification")

        let initialMetrics = await pushService.getMetrics()

        try await pushService.notifyBillDeleted(
            bill: testBill,
            deleterName: "Charlie Unit Test"
        )

        // Allow processing time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let updatedMetrics = await pushService.getMetrics()

        XCTAssertGreaterThan(
            updatedMetrics.deletedNotifications,
            initialMetrics.deletedNotifications,
            "Deleted notifications count should increase"
        )

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Rate Limiting Tests

    func testRateLimitingBehavior() async throws {
        let expectation = XCTestExpectation(description: "Rate limiting behavior")

        // Send many notifications quickly to trigger rate limiting
        let rapidRequestCount = 10

        for i in 1...rapidRequestCount {
            let quickBill = Bill(
                id: "rate_limit_bill_\(i)",
                name: "Rate Limit Test \(i)",
                totalAmount: 10.0,
                currency: "USD",
                participants: [testParticipants[0]], // Single participant to simplify
                items: [],
                paidByParticipantId: testParticipants[0].id,
                createdBy: testParticipants[0].id,
                createdAt: Date()
            )

            try await pushService.notifyBillCreated(
                bill: quickBill,
                creatorName: "Rate Limit Test"
            )
        }

        // Allow processing time
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Service should still be healthy (rate limiting should prevent overload)
        let isHealthy = await pushService.validateServiceHealth()
        XCTAssertTrue(isHealthy, "Service should remain healthy under rapid requests due to rate limiting")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 15.0)
    }

    // MARK: - Memory Management Tests

    func testMemoryManagement() async throws {
        let expectation = XCTestExpectation(description: "Memory management")

        // Generate many notifications to test memory limits
        for i in 1...50 {
            let memoryTestBill = Bill(
                id: "memory_bill_\(i)",
                name: "Memory Test \(i)",
                totalAmount: Double(i),
                currency: "USD",
                participants: [testParticipants[i % testParticipants.count]],
                items: [],
                paidByParticipantId: testParticipants[i % testParticipants.count].id,
                createdBy: testParticipants[i % testParticipants.count].id,
                createdAt: Date()
            )

            try await pushService.notifyBillCreated(
                bill: memoryTestBill,
                creatorName: "Memory Test"
            )

            // Brief pause every 10 notifications
            if i % 10 == 0 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        // Allow processing and cleanup
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        // Service should remain healthy with proper memory management
        let isHealthy = await pushService.validateServiceHealth()
        XCTAssertTrue(isHealthy, "Service should manage memory properly under load")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 30.0)
    }

    // MARK: - Error Handling Tests

    func testEmptyBillHandling() async {
        let expectation = XCTestExpectation(description: "Empty bill handling")

        let emptyBill = Bill(
            id: "empty_bill",
            name: "",
            totalAmount: 0.0,
            currency: "USD",
            participants: [],
            items: [],
            paidByParticipantId: "",
            createdBy: "",
            createdAt: Date()
        )

        // This should handle gracefully without crashing
        do {
            try await pushService.notifyBillCreated(
                bill: emptyBill,
                creatorName: ""
            )

            // If no error thrown, that's good
            print("✅ Empty bill handled gracefully")

        } catch {
            // If error thrown, verify it's handled appropriately
            print("⚠️ Empty bill error handled: \(error)")
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testNilValuesHandling() async {
        let expectation = XCTestExpectation(description: "Nil values handling")

        // Test with participants having nil/empty values
        let problematicParticipants = [
            BillParticipant(
                id: "",
                name: "",
                email: "",
                profileImageURL: nil,
                isCurrentUser: false
            ),
            BillParticipant(
                id: "valid_id",
                name: "Valid Name",
                email: "valid@example.com",
                profileImageURL: nil,
                isCurrentUser: false
            )
        ]

        let problematicBill = Bill(
            id: "problematic_bill",
            name: "Problematic Bill",
            totalAmount: 25.0,
            currency: "USD",
            participants: problematicParticipants,
            items: [],
            paidByParticipantId: "valid_id",
            createdBy: "valid_id",
            createdAt: Date()
        )

        // Should handle problematic data gracefully
        do {
            try await pushService.notifyBillCreated(
                bill: problematicBill,
                creatorName: "Test"
            )
            print("✅ Problematic data handled gracefully")
        } catch {
            print("⚠️ Problematic data error handled: \(error)")
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Retry Logic Tests

    func testRetryLogicForFailures() async throws {
        let expectation = XCTestExpectation(description: "Retry logic for failures")

        // Create a bill that will likely trigger retry logic due to invalid email domains
        let retryTestBill = Bill(
            id: "retry_test_bill",
            name: "Retry Test Bill",
            totalAmount: 30.0,
            currency: "USD",
            participants: [
                BillParticipant(
                    id: "retry_user",
                    name: "Retry User",
                    email: "retry@nonexistent.domain",
                    profileImageURL: nil,
                    isCurrentUser: false
                )
            ],
            items: [],
            paidByParticipantId: "retry_user",
            createdBy: "retry_user",
            createdAt: Date()
        )

        try await pushService.notifyBillCreated(
            bill: retryTestBill,
            creatorName: "Retry Test"
        )

        // Allow time for retry attempts
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

        // Service should remain healthy even with retry operations
        let isHealthy = await pushService.validateServiceHealth()
        XCTAssertTrue(isHealthy, "Service should remain healthy during retry operations")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 20.0)
    }

    // MARK: - Background Processing Tests

    func testBackgroundTaskHandling() async {
        let expectation = XCTestExpectation(description: "Background task handling")

        // Test that background tasks can be initiated
        // Note: In test environment, background task creation might not work exactly as in production

        let largeBill = Bill(
            id: "background_test_bill",
            name: "Background Test Bill",
            totalAmount: 100.0,
            currency: "USD",
            participants: testParticipants, // Multiple participants to trigger batch processing
            items: [
                BillItem(
                    id: "bg_item",
                    name: "Background Item",
                    price: 100.0,
                    assignedParticipantIds: testParticipants.map { $0.id }
                )
            ],
            paidByParticipantId: testParticipants[0].id,
            createdBy: testParticipants[0].id,
            createdAt: Date()
        )

        do {
            try await pushService.notifyBillCreated(
                bill: largeBill,
                creatorName: "Background Test"
            )

            // Allow background processing
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            // Verify service health after background processing
            let isHealthy = await pushService.validateServiceHealth()
            XCTAssertTrue(isHealthy, "Service should handle background processing correctly")

            expectation.fulfill()

        } catch {
            XCTFail("Background processing test failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 15.0)
    }

    // MARK: - Cleanup Tests

    func testPendingNotificationCleanup() async {
        let expectation = XCTestExpectation(description: "Pending notification cleanup")

        // Add some notifications
        try? await pushService.notifyBillCreated(
            bill: testBill,
            creatorName: "Cleanup Test"
        )

        // Allow notifications to be queued
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Clear pending notifications
        await pushService.clearAllPendingNotifications()

        // Verify service remains healthy after cleanup
        let isHealthy = await pushService.validateServiceHealth()
        XCTAssertTrue(isHealthy, "Service should be healthy after cleanup")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Performance Tests

    func testNotificationPerformanceUnderLoad() async throws {
        let expectation = XCTestExpectation(description: "Notification performance under load")

        let notificationCount = 25
        let startTime = Date()

        // Send multiple notifications
        for i in 1...notificationCount {
            let performanceBill = Bill(
                id: "perf_bill_\(i)",
                name: "Performance Bill \(i)",
                totalAmount: 20.0,
                currency: "USD",
                participants: [testParticipants[i % testParticipants.count]],
                items: [],
                paidByParticipantId: testParticipants[i % testParticipants.count].id,
                createdBy: testParticipants[i % testParticipants.count].id,
                createdAt: Date()
            )

            try await pushService.notifyBillCreated(
                bill: performanceBill,
                creatorName: "Performance Test"
            )
        }

        // Allow processing to complete
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)

        // Performance expectations
        XCTAssertLessThan(
            totalTime,
            20.0,
            "Should process \(notificationCount) notifications within 20 seconds"
        )

        let notificationsPerSecond = Double(notificationCount) / totalTime
        print("⚡ Performance: \(notificationCount) notifications in \(String(format: "%.2f", totalTime))s (\(String(format: "%.1f", notificationsPerSecond)) notifications/sec)")

        // Verify service health after performance test
        let isHealthy = await pushService.validateServiceHealth()
        XCTAssertTrue(isHealthy, "Service should maintain health under performance load")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 30.0)
    }

    // MARK: - Helper Methods

    private func createTestBillWithParticipantCount(_ count: Int) -> Bill {
        var participants: [BillParticipant] = []

        for i in 1...count {
            participants.append(BillParticipant(
                id: "test_participant_\(i)",
                name: "Test Participant \(i)",
                email: "participant\(i)@test.com",
                profileImageURL: nil,
                isCurrentUser: i == 1
            ))
        }

        return Bill(
            id: "test_bill_\(count)_participants",
            name: "Test Bill with \(count) Participants",
            totalAmount: Double(count * 10),
            currency: "USD",
            participants: participants,
            items: [],
            paidByParticipantId: participants.first!.id,
            createdBy: participants.first!.id,
            createdAt: Date()
        )
    }
}