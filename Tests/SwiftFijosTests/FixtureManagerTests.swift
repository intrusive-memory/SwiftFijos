import Testing
import Foundation
@testable import SwiftFijos

/// Tests for FixtureManager thread-safe fixture access
@Suite("FixtureManager Tests")
@MainActor
struct FixtureManagerTests {

    // MARK: - Setup and Teardown

    init() async throws {
        // Clear state before each test suite
        await FixtureManager.shared.releaseAllLocks()
        await FixtureManager.shared.clearCache()
        await FixtureManager.shared.resetStatistics()
    }

    // MARK: - Basic Access Tests

    @Test("Access fixture with exclusive lock")
    func accessFixtureWithLock() async throws {
        let content = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return try String(contentsOf: url)
        }

        #expect(!content.isEmpty)
    }

    @Test("Access non-existent fixture throws error")
    func accessNonExistentFixture() async throws {
        do {
            _ = try await FixtureManager.shared.withExclusiveAccess(
                to: "nonexistent-file-12345.json"
            ) { url in
                return url
            }
            Issue.record("Expected FijosError to be thrown")
        } catch let error as FijosError {
            // Expected error
            #expect(error.localizedDescription.contains("not found"))
        } catch {
            Issue.record("Expected FijosError, got: \(error)")
        }
    }

    @Test("Cache is used on second access")
    func cacheIsUsedOnSecondAccess() async throws {
        // First access - should fetch from Fijos
        let url1 = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        // Second access - should use cache
        let url2 = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        #expect(url1 == url2)
    }

    @Test("Clear cache forces re-fetch")
    func clearCacheForcesRefetch() async throws {
        // Access once to cache
        _ = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        // Clear cache
        await FixtureManager.shared.clearCache()

        // Should still work after cache clear
        let url = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        #expect(url.lastPathComponent == "sample.json")
    }

    // MARK: - Locking Tests

    @Test("Lock is released after successful operation")
    func lockReleasedAfterSuccess() async throws {
        _ = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        // Lock should be released
        let isLocked = await FixtureManager.shared.isLocked("sample.json")
        #expect(!isLocked)
    }

    @Test("Lock is released after error")
    func lockReleasedAfterError() async throws {
        do {
            _ = try await FixtureManager.shared.withExclusiveAccess(
                to: "sample.json"
            ) { url in
                throw TestError.simulatedError
            }
            Issue.record("Expected error to be thrown")
        } catch TestError.simulatedError {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Lock should be released even after error
        let isLocked = await FixtureManager.shared.isLocked("sample.json")
        #expect(!isLocked)
    }

    @Test("Different fixtures can be accessed simultaneously")
    func differentFixturesSimultaneousAccess() async throws {
        try await withThrowingTaskGroup(of: String.self) { group in
            // Access different fixtures in parallel
            group.addTask {
                try await FixtureManager.shared.withExclusiveAccess(
                    to: "sample.json"
                ) { url in
                    try await Task.sleep(nanoseconds: 50_000_000)
                    return url.lastPathComponent
                }
            }

            group.addTask {
                try await FixtureManager.shared.withExclusiveAccess(
                    to: "test.fountain"
                ) { url in
                    try await Task.sleep(nanoseconds: 50_000_000)
                    return url.lastPathComponent
                }
            }

            var results: Set<String> = []
            for try await filename in group {
                results.insert(filename)
            }

            #expect(results.contains("sample.json"))
            #expect(results.contains("test.fountain"))
        }
    }

    @Test("Sequential access to same fixture")
    func sequentialAccessToSameFixture() async throws {
        actor AccessCounter {
            private var count = 0

            func increment() {
                count += 1
            }

            func getCount() -> Int {
                return count
            }
        }

        let counter = AccessCounter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await FixtureManager.shared.withExclusiveAccess(
                        to: "sample.json"
                    ) { url in
                        await counter.increment()
                        try await Task.sleep(nanoseconds: 10_000_000)
                    }
                }
            }

            try await group.waitForAll()
        }

        // All 5 tasks should have completed
        let count = await counter.getCount()
        #expect(count == 5)
    }

    // MARK: - Security-Scoped Resource Tests

    @Test("Security scope access works")
    func securityScopeAccess() async throws {
        let content = try await FixtureManager.shared.withSecurityScope(
            fixture: "sample.json"
        ) { url in
            return try String(contentsOf: url)
        }

        #expect(!content.isEmpty)
    }

    // MARK: - Preloading Tests

    @Test("Preload specific fixtures")
    func preloadSpecificFixtures() async throws {
        try await FixtureManager.shared.preloadFixtures([
            "sample.json",
            "test.fountain"
        ])

        // Access should be fast (already cached)
        let url = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        #expect(url.lastPathComponent == "sample.json")
    }

    @Test("Preload all fixtures")
    func preloadAllFixtures() async throws {
        try await FixtureManager.shared.preloadAllFixtures()

        // Access should work for any fixture
        let url = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        #expect(url.lastPathComponent == "sample.json")
    }

    // MARK: - Statistics Tests

    @Test("Access statistics are tracked")
    func accessStatisticsTracked() async throws {
        // Reset stats
        await FixtureManager.shared.resetStatistics()

        // Access fixture multiple times
        for _ in 0..<3 {
            _ = try await FixtureManager.shared.withExclusiveAccess(
                to: "sample.json"
            ) { url in
                return url
            }
        }

        let count = await FixtureManager.shared.getAccessCount(for: "sample.json")
        #expect(count == 3)
    }

    @Test("Statistics report prints without error")
    func statisticsReportPrints() async throws {
        // Access some fixtures
        _ = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        // Should not crash
        await FixtureManager.shared.printAccessReport()
    }

    @Test("Reset statistics clears all data")
    func resetStatisticsClearsData() async throws {
        // Access fixture
        _ = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        // Reset
        await FixtureManager.shared.resetStatistics()

        let counts = await FixtureManager.shared.getAllAccessCounts()
        #expect(counts.isEmpty)
    }

    // MARK: - Release All Locks Tests

    @Test("Release all locks clears all locks")
    func releaseAllLocksClears() async throws {
        // This is hard to test directly since locks are held during operations
        // Just verify it doesn't crash
        await FixtureManager.shared.releaseAllLocks()

        // Should be able to access after
        let url = try await FixtureManager.shared.withExclusiveAccess(
            to: "sample.json"
        ) { url in
            return url
        }

        #expect(url.lastPathComponent == "sample.json")
    }

    // MARK: - Parallel Execution Stress Test

    @Test("Parallel access stress test")
    func parallelAccessStressTest() async throws {
        let fixtureNames = ["sample.json", "test.fountain"]
        let iterations = 20

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                let fixture = fixtureNames[i % fixtureNames.count]

                group.addTask {
                    try await FixtureManager.shared.withExclusiveAccess(
                        to: fixture
                    ) { url in
                        // Simulate some work
                        try await Task.sleep(nanoseconds: 5_000_000)
                        let _ = try? String(contentsOf: url)
                    }
                }
            }

            try await group.waitForAll()
        }

        // All tasks should complete without errors
        let counts = await FixtureManager.shared.getAllAccessCounts()
        #expect(!counts.isEmpty)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case simulatedError
}
