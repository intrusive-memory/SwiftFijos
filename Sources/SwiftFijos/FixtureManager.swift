import Foundation

/// Thread-safe fixture access manager for parallel test execution.
///
/// When using Swift Testing with parallel test execution, `FixtureManager` coordinates
/// fixture access to prevent conflicts when multiple tests access the same file simultaneously.
///
/// ## Usage
///
/// ```swift
/// import Testing
/// import SwiftFijos
///
/// @Test func importFile() async throws {
///     let document = try await FixtureManager.shared.withExclusiveAccess(
///         to: "test.json"
///     ) { url in
///         let data = try Data(contentsOf: url)
///         return try JSONDecoder().decode(Document.self, from: data)
///     }
///
///     #expect(document != nil)
/// }
/// ```
///
/// ## Features
///
/// - **Exclusive Access**: Only one test can access a fixture at a time
/// - **Automatic Locking**: Waits for lock acquisition, releases automatically
/// - **URL Caching**: Caches fixture URLs for better performance
/// - **Security-Scoped Resources**: macOS security-scoped bookmark support
///
@globalActor
public actor FixtureManager {

    /// Shared singleton instance
    public static let shared = FixtureManager()

    // MARK: - Private State

    /// Currently locked fixtures
    private var lockedFixtures: Set<String> = []

    /// Cached fixture URLs
    private var cachedURLs: [String: URL] = [:]

    /// Access counts for debugging
    private var accessCounts: [String: Int] = [:]

    // MARK: - Public API

    /// Access a fixture with exclusive lock.
    ///
    /// Waits if another test is currently accessing this fixture, then performs
    /// the operation with the lock held. The lock is automatically released after
    /// the operation completes, even if an error is thrown.
    ///
    /// - Parameters:
    ///   - fixture: The fixture filename (e.g., "test.json")
    ///   - path: The file path to start searching from. Defaults to `#filePath`.
    ///   - operation: The async operation to perform with the fixture URL
    /// - Returns: The result of the operation
    /// - Throws: Any error thrown by the operation or `FijosError` if fixture not found
    ///
    /// ## Example
    ///
    /// ```swift
    /// let data = try await FixtureManager.shared.withExclusiveAccess(
    ///     to: "test.json"
    /// ) { url in
    ///     return try Data(contentsOf: url)
    /// }
    /// ```
    public func withExclusiveAccess<T>(
        to fixture: String,
        from path: String = #filePath,
        perform operation: @Sendable (URL) async throws -> T
    ) async throws -> T {
        // Wait for exclusive access
        await waitForLock(on: fixture)
        defer { releaseLock(on: fixture) }

        // Update access count
        accessCounts[fixture, default: 0] += 1

        // Get fixture URL (cached or fresh)
        let url = try cachedURL(for: fixture, from: path)

        // Perform operation with lock held
        return try await operation(url)
    }

    /// Access fixture with security-scoped resource handling (macOS only).
    ///
    /// On macOS, this method starts security-scoped resource access before calling
    /// the operation and stops it afterward. On other platforms, it behaves the same
    /// as `withExclusiveAccess`.
    ///
    /// - Parameters:
    ///   - fixture: The fixture filename (e.g., "test.json")
    ///   - path: The file path to start searching from. Defaults to `#filePath`.
    ///   - operation: The async operation to perform with the fixture URL
    /// - Returns: The result of the operation
    /// - Throws: Any error thrown by the operation or `FijosError` if fixture not found
    ///
    /// ## Example
    ///
    /// ```swift
    /// let document = try await FixtureManager.shared.withSecurityScope(
    ///     fixture: "test.fountain"
    /// ) { url in
    ///     return try await DocumentImportService.importDocument(from: url)
    /// }
    /// ```
    public func withSecurityScope<T>(
        fixture: String,
        from path: String = #filePath,
        perform operation: @Sendable (URL) async throws -> T
    ) async throws -> T {
        // Wait for exclusive access
        await waitForLock(on: fixture)
        defer { releaseLock(on: fixture) }

        // Update access count
        accessCounts[fixture, default: 0] += 1

        // Get fixture URL (cached or fresh)
        let url = try cachedURL(for: fixture, from: path)

        #if os(macOS)
        // Start security-scoped access on macOS
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #endif

        // Perform operation with lock held
        return try await operation(url)
    }

    /// Check if a fixture is currently locked by another test.
    ///
    /// - Parameter fixture: The fixture filename to check
    /// - Returns: `true` if the fixture is locked, `false` otherwise
    public func isLocked(_ fixture: String) -> Bool {
        return lockedFixtures.contains(fixture)
    }

    /// Release all fixture locks.
    ///
    /// Useful for test cleanup or debugging. Should not be needed in normal usage
    /// as locks are automatically released after operations complete.
    public func releaseAllLocks() {
        lockedFixtures.removeAll()
    }

    /// Clear the fixture URL cache.
    ///
    /// Forces the next access to re-discover fixture URLs. Useful if fixtures
    /// are moved or modified during test execution.
    public func clearCache() {
        cachedURLs.removeAll()
    }

    /// Preload fixtures into cache for faster access.
    ///
    /// Useful for test suite setup to avoid repeated fixture discovery.
    ///
    /// - Parameters:
    ///   - names: Array of fixture filenames to preload
    ///   - path: The file path to start searching from. Defaults to `#filePath`.
    /// - Throws: `FijosError` if any fixture cannot be found
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Suite(.serialized)
    /// struct MyTests {
    ///     init() async throws {
    ///         try await FixtureManager.shared.preloadFixtures([
    ///             "test1.json",
    ///             "test2.json",
    ///             "test3.json"
    ///         ])
    ///     }
    /// }
    /// ```
    public func preloadFixtures(
        _ names: [String],
        from path: String = #filePath
    ) async throws {
        for name in names {
            _ = try cachedURL(for: name, from: path)
        }
    }

    /// Preload all fixtures in the Fixtures directory.
    ///
    /// - Parameter path: The file path to start searching from. Defaults to `#filePath`.
    /// - Throws: `FijosError` if the Fixtures directory cannot be found
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Suite(.serialized)
    /// struct MyTests {
    ///     init() async throws {
    ///         try await FixtureManager.shared.preloadAllFixtures()
    ///     }
    /// }
    /// ```
    public func preloadAllFixtures(
        from path: String = #filePath
    ) async throws {
        let fixtures = try Fijos.listFixtures(from: path)
        for fixture in fixtures {
            cachedURLs[fixture.id] = fixture.url
        }
    }

    // MARK: - Statistics

    /// Get access count for a specific fixture
    ///
    /// - Parameter fixture: The fixture filename
    /// - Returns: Number of times this fixture was accessed
    public func getAccessCount(for fixture: String) -> Int {
        return accessCounts[fixture, default: 0]
    }

    /// Get all fixture access counts
    ///
    /// - Returns: Dictionary mapping fixture names to access counts
    public func getAllAccessCounts() -> [String: Int] {
        return accessCounts
    }

    /// Print a formatted report of fixture access statistics.
    ///
    /// Useful for debugging parallel test execution and identifying bottlenecks.
    public func printAccessReport() {
        // Column width constants for formatting
        let fixtureColumnWidth = 40
        let accessesColumnWidth = 10
        let ellipsisSuffix = "..."
        let maxFixtureNameLength = fixtureColumnWidth - ellipsisSuffix.count

        let sorted = accessCounts.sorted { $0.value > $1.value }

        guard !sorted.isEmpty else {
            print("📊 Fixture Access Report: No fixtures accessed")
            return
        }

        print("📊 Fixture Access Report:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(String(format: "%-\(fixtureColumnWidth)s %\(accessesColumnWidth)s", "Fixture", "Accesses"))
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for (fixture, count) in sorted {
            let fixtureName = fixture.count > fixtureColumnWidth
                ? String(fixture.prefix(maxFixtureNameLength)) + ellipsisSuffix
                : fixture

            print(String(format: "%-\(fixtureColumnWidth)s %\(accessesColumnWidth)d", fixtureName, count))
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total: \(sorted.reduce(0) { $0 + $1.value }) accesses across \(sorted.count) fixtures")
    }

    /// Reset all statistics.
    ///
    /// Useful for benchmarking specific test runs.
    public func resetStatistics() {
        accessCounts.removeAll()
    }

    // MARK: - Private Implementation

    /// Wait for exclusive lock on fixture
    private func waitForLock(on fixture: String) async {
        while lockedFixtures.contains(fixture) {
            // Wait 10ms before checking again
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        lockedFixtures.insert(fixture)
    }

    /// Release lock on fixture
    private func releaseLock(on fixture: String) {
        lockedFixtures.remove(fixture)
    }

    /// Get cached URL or fetch from Fijos
    private func cachedURL(for fixture: String, from path: String) throws -> URL {
        if let cached = cachedURLs[fixture] {
            return cached
        }

        let url = try Fijos.getFixture(fixture, from: path)
        cachedURLs[fixture] = url
        return url
    }
}
