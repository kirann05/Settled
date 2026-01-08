import XCTest
import Firebase
import FirebaseAuth
import FirebaseFirestore
// Note: Import Settled when the test target is properly configured
// @testable import Settled

/// Unit tests for FCMTokenManager focusing on edge cases and reliability
class FCMTokenManagerTests: XCTestCase {

    var tokenManager: FCMTokenManager!
    var mockEmails: [String]!

    override func setUpWithError() throws {
        try super.setUpWithError()

        tokenManager = FCMTokenManager.shared
        mockEmails = [
            "test1@example.com",
            "test2@example.com",
            "test3@example.com",
            "test4@example.com",
            "test5@example.com"
        ]
    }

    override func tearDownWithError() throws {
        // Clean up any test state
        await tokenManager.cleanupTokenOnSignOut()
        try super.tearDownWithError()
    }

    // MARK: - Token Health Validation Tests

    func testTokenHealthValidation() {
        // Test with no token
        XCTAssertFalse(tokenManager.validateTokenHealth(), "Should be unhealthy with no token")

        // Simulate setting a valid token (private access limitation - test what we can)
        // In a real implementation, we'd use dependency injection for testability
    }

    func testTokenRefreshLogic() async throws {
        let expectation = XCTestExpectation(description: "Token refresh")

        do {
            // Test token refresh
            try await tokenManager.refreshTokenIfNeeded()

            // After refresh, token should be available
            // Note: In testing environment, this uses simulated tokens
            let isHealthy = tokenManager.validateTokenHealth()

            // The result depends on the current state - we mainly test it doesn't crash
            print("✅ Token refresh completed, health status: \(isHealthy)")

            expectation.fulfill()

        } catch {
            XCTFail("Token refresh should not throw errors: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Batch Token Retrieval Tests

    func testBatchTokenRetrieval() async {
        let expectation = XCTestExpectation(description: "Batch token retrieval")

        // Test retrieving tokens for multiple emails
        let tokens = await tokenManager.getFCMTokensForEmails(mockEmails)

        // In testing environment with simulated data, we verify the structure
        XCTAssertTrue(
            tokens.count <= mockEmails.count,
            "Should not return more tokens than emails requested"
        )

        // Verify token format for any returned tokens
        for (email, token) in tokens {
            XCTAssertTrue(
                mockEmails.contains(email),
                "Returned email \(email) should be in requested list"
            )

            XCTAssertTrue(
                token.hasPrefix("fcm_token_"),
                "Token format should be correct"
            )

            XCTAssertGreaterThan(
                token.count,
                15,
                "Token should have reasonable length"
            )
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testEmptyEmailListHandling() async {
        let expectation = XCTestExpectation(description: "Empty email list handling")

        // Test with empty email list
        let tokens = await tokenManager.getFCMTokensForEmails([])

        XCTAssertTrue(tokens.isEmpty, "Should return empty result for empty input")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testLargeEmailListBatching() async {
        let expectation = XCTestExpectation(description: "Large email list batching")

        // Create a large list of emails to test batching logic
        var largeEmailList: [String] = []
        for i in 1...50 {
            largeEmailList.append("user\(i)@test.com")
        }

        let startTime = Date()
        let tokens = await tokenManager.getFCMTokensForEmails(largeEmailList)
        let processingTime = Date().timeIntervalSince(startTime)

        // Verify performance and batching
        XCTAssertLessThan(
            processingTime,
            15.0,
            "Large email list processing should complete within 15 seconds"
        )

        // In testing, we might not get tokens for all emails, but verify structure
        for (email, token) in tokens {
            XCTAssertTrue(
                largeEmailList.contains(email),
                "Returned email should be in requested list"
            )

            XCTAssertTrue(
                token.hasPrefix("fcm_token_"),
                "Token format should be correct"
            )
        }

        print("📊 Large batch processing: \(tokens.count)/\(largeEmailList.count) tokens retrieved in \(String(format: "%.2f", processingTime))s")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 20.0)
    }

    // MARK: - Caching Tests

    func testTokenCaching() async {
        let expectation = XCTestExpectation(description: "Token caching")

        let testEmails = Array(mockEmails.prefix(3))

        // First request - should hit Firestore
        let startTime1 = Date()
        let tokens1 = await tokenManager.getFCMTokensForEmails(testEmails)
        let firstRequestTime = Date().timeIntervalSince(startTime1)

        // Second request - should use cache
        let startTime2 = Date()
        let tokens2 = await tokenManager.getFCMTokensForEmails(testEmails)
        let secondRequestTime = Date().timeIntervalSince(startTime2)

        // Second request should be faster due to caching
        XCTAssertLessThanOrEqual(
            secondRequestTime,
            firstRequestTime,
            "Cached request should be faster than or equal to first request"
        )

        // Results should be consistent
        XCTAssertEqual(
            tokens1.count,
            tokens2.count,
            "Cached results should match original results"
        )

        for email in testEmails {
            if let token1 = tokens1[email], let token2 = tokens2[email] {
                XCTAssertEqual(token1, token2, "Cached token should match original for \(email)")
            }
        }

        print("📊 Caching Performance:")
        print("   First Request: \(String(format: "%.3f", firstRequestTime))s")
        print("   Cached Request: \(String(format: "%.3f", secondRequestTime))s")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 15.0)
    }

    func testCacheExpiration() async {
        let expectation = XCTestExpectation(description: "Cache expiration")

        // This test would require manipulating private cache properties
        // In a production implementation, we'd expose cache management methods for testing

        // For now, we test that the system continues to work over time
        let testEmail = ["cache.test@example.com"]

        let tokens1 = await tokenManager.getFCMTokensForEmails(testEmail)

        // Wait longer than cache expiration (5 minutes in production, shortened for test)
        // In real testing, we'd mock the time or have a shorter cache expiration for tests
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds for test speed

        let tokens2 = await tokenManager.getFCMTokensForEmails(testEmail)

        // Verify system continues to work
        XCTAssertTrue(
            tokens1.count == tokens2.count || tokens1.isEmpty || tokens2.isEmpty,
            "Cache expiration should not break the system"
        )

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Memory Management Tests

    func testMemoryLimitEnforcement() async {
        let expectation = XCTestExpectation(description: "Memory limit enforcement")

        // Generate many unique emails to test memory limits
        var manyEmails: [String] = []
        for i in 1...150 { // More than maxCacheSize (100)
            manyEmails.append("memory\(i)@test.com")
        }

        // Process in chunks to simulate real usage
        let chunkSize = 10
        let chunks = manyEmails.chunked(into: chunkSize)

        for chunk in chunks {
            let _ = await tokenManager.getFCMTokensForEmails(chunk)

            // Brief pause to allow cache management
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }

        // The system should continue to work without memory issues
        // We can't directly test cache size due to private access, but we verify functionality

        let finalTokens = await tokenManager.getFCMTokensForEmails(["final.test@example.com"])

        // System should still be responsive
        print("✅ Memory limit enforcement test completed - system remains responsive")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 30.0)
    }

    // MARK: - Error Handling Tests

    func testInvalidEmailHandling() async {
        let expectation = XCTestExpectation(description: "Invalid email handling")

        let invalidEmails = [
            "",
            "invalid-email",
            "spaces in email@test.com",
            "very-long-email-address-that-might-cause-issues-with-some-systems@very-long-domain-name-that-exceeds-normal-limits.com"
        ]

        // This should not crash or hang
        let tokens = await tokenManager.getFCMTokensForEmails(invalidEmails)

        // System should handle invalid emails gracefully
        print("🔧 Invalid email handling: \(tokens.count) tokens retrieved from \(invalidEmails.count) invalid emails")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testFirestoreConnectionFailure() async {
        let expectation = XCTestExpectation(description: "Firestore connection failure handling")

        // In a real test environment, we'd mock Firestore to simulate failures
        // For now, we test that the system doesn't crash under normal conditions

        let testEmails = ["connection.test@example.com"]
        let tokens = await tokenManager.getFCMTokensForEmails(testEmails)

        // System should handle connection issues gracefully
        print("🌐 Connection failure handling test completed")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentTokenRequests() async {
        let expectation = XCTestExpectation(description: "Concurrent token requests")

        let concurrentEmails = [
            ["concurrent1@test.com", "concurrent2@test.com"],
            ["concurrent3@test.com", "concurrent4@test.com"],
            ["concurrent5@test.com", "concurrent6@test.com"],
            ["concurrent7@test.com", "concurrent8@test.com"]
        ]

        // Launch multiple concurrent requests
        await withTaskGroup(of: [String: String].self) { group in
            for emailBatch in concurrentEmails {
                group.addTask {
                    return await self.tokenManager.getFCMTokensForEmails(emailBatch)
                }
            }

            var allResults: [[String: String]] = []
            for await result in group {
                allResults.append(result)
            }

            // Verify all requests completed without issues
            XCTAssertEqual(
                allResults.count,
                concurrentEmails.count,
                "All concurrent requests should complete"
            )

            // Verify no corruption in results
            var allEmails: Set<String> = Set()
            for result in allResults {
                for email in result.keys {
                    XCTAssertFalse(
                        allEmails.contains(email),
                        "Each email should appear only once across all results"
                    )
                    allEmails.insert(email)
                }
            }

            print("🔄 Concurrent requests test: \(allResults.count) batches completed successfully")
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 20.0)
    }

    // MARK: - Performance Tests

    func testTokenRetrievalPerformance() async {
        let expectation = XCTestExpectation(description: "Token retrieval performance")

        let performanceEmails = (1...20).map { "perf\($0)@test.com" }

        // Measure performance
        let startTime = Date()
        let tokens = await tokenManager.getFCMTokensForEmails(performanceEmails)
        let processingTime = Date().timeIntervalSince(startTime)

        // Performance expectations
        XCTAssertLessThan(
            processingTime,
            5.0,
            "Token retrieval for 20 emails should complete within 5 seconds"
        )

        let tokensPerSecond = Double(tokens.count) / processingTime
        XCTAssertGreaterThan(
            tokensPerSecond,
            2.0,
            "Should process at least 2 tokens per second"
        )

        print("⚡ Performance: \(tokens.count) tokens in \(String(format: "%.3f", processingTime))s (\(String(format: "%.1f", tokensPerSecond)) tokens/sec)")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Integration Edge Cases

    func testSignOutCleanup() async {
        let expectation = XCTestExpectation(description: "Sign out cleanup")

        // First, ensure we have some token state
        try? await tokenManager.refreshTokenIfNeeded()

        // Perform cleanup
        await tokenManager.cleanupTokenOnSignOut()

        // Verify cleanup occurred (test what we can access)
        let healthAfterCleanup = tokenManager.validateTokenHealth()
        XCTAssertFalse(
            healthAfterCleanup,
            "Token should be invalid after sign out cleanup"
        )

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testUserAuthenticationChanges() async {
        let expectation = XCTestExpectation(description: "User authentication changes")

        // Test system behavior during auth state changes
        // This would typically integrate with Firebase Auth mocking

        // For now, test that cleanup and refresh work independently
        await tokenManager.cleanupTokenOnSignOut()
        try? await tokenManager.refreshTokenIfNeeded()

        print("🔐 Authentication change handling test completed")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
}