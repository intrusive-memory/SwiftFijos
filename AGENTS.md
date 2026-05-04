# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftFijos codebase.

**Current Version**: 1.2.0 (February 2026)

---

## Project Overview

SwiftFijos is a lightweight Swift package for managing and discovering test fixtures in Swift packages and Xcode projects. It provides thread-safe fixture access with support for parallel test execution using Swift Testing.

## Project Structure

- `Sources/SwiftFijos/Fijos.swift` -- Core fixture discovery and access API
- `Sources/SwiftFijos/FixtureManager.swift` -- Thread-safe fixture manager with exclusive locking
- `Tests/SwiftFijosTests/` -- Test suite
- `Fixtures/` -- Test fixture files
- `Package.swift` -- Package manifest (Swift 6.2+, iOS 26.0+, macOS 26.0+)

## Key Components

| File | Purpose |
|------|---------|
| `Fijos.swift` | Static methods for fixture discovery via CI env vars, bundle search, file system traversal; supports filtering by extension, pattern matching, listing available extensions; CI detection utilities |
| `FixtureManager.swift` | Actor-based thread-safe fixture access; exclusive locking with automatic waiting; URL caching for performance; security-scoped resource support (macOS); preloading and access statistics |
| `Fixture` (struct) | Identifiable fixture metadata: `id` (full filename), `name` (without extension), `fileExtension`, `url` |
| `FijosError` (enum) | Error types: `fixturesDirectoryNotFound`, `fixtureNotFound`, `couldNotCreateTemporaryFixture`, `couldNotCreateDirectory`, `couldNotReadFile`, `couldNotWriteToFile` |

## Fixture Discovery

Discovery strategies are executed in priority order:

1. **CI Environment Variable**: Checks `CI_PRIMARY_REPOSITORY_PATH` (Xcode Cloud) and constructs path to Fixtures directory
2. **Bundle Search**: Searches all accessible bundles for a Fixtures directory resource (requires "Fixtures" folder in test target's "Copy Bundle Resources" build phase)
3. **File System Traversal**: Fallback for local development; traverses up from `#filePath` up to 10 levels looking for Fixtures directory

## API Overview

### Fijos Static Methods

| Method | Description |
|--------|-------------|
| `getFixturesDirectory(from:)` | Returns URL to Fixtures directory using discovery strategies |
| `getFixture(_:from:)` | Get fixture by full filename (e.g., "sample.json") |
| `getFixture(_:extension:from:)` | Get fixture by name and extension separately |
| `listFixtures(from:)` | List all fixtures (excludes symlinks), sorted by name |
| `listFixtures(withExtension:from:)` | Filter fixtures by extension (case-insensitive) |
| `findFixtures(matching:from:)` | Search fixtures by name pattern (case-insensitive substring match) |
| `availableExtensions(from:)` | List all unique extensions present in Fixtures directory |

### Fijos CI Detection

| Property | Description |
|----------|-------------|
| `isCI` | True if running in CI (GitHub Actions, GitLab, CircleCI, Jenkins, Buildkite, Travis, Xcode Cloud) |
| `isRunningTests` | True if tests are executing (detects XCTest, Swift Testing, test bundles, swift-testing runner) |
| `ciRepositoryPath` | CI repository path from various CI environment variables |

### FixtureManager Methods

| Method | Description |
|--------|-------------|
| `withExclusiveAccess(to:from:perform:)` | Access fixture with exclusive lock; waits if locked by another test; automatically releases lock after operation completes |
| `withSecurityScope(fixture:from:perform:)` | Access fixture with security-scoped resource handling (macOS only); calls `startAccessingSecurityScopedResource()` before operation, `stopAccessingSecurityScopedResource()` after |
| `isLocked(_:)` | Check if fixture is currently locked |
| `releaseAllLocks()` | Release all locks (for cleanup) |
| `clearCache()` | Clear the fixture URL cache |
| `preloadFixtures(_:from:)` | Preload specific fixtures into cache |
| `preloadAllFixtures(from:)` | Preload all fixtures into cache |
| `getAccessCount(for:)` | Get access count for a specific fixture |
| `getAllAccessCounts()` | Get all access counts as dictionary |
| `printAccessReport()` | Print formatted statistics report with fixture names and access counts |
| `resetStatistics()` | Reset all access statistics |

## Usage Patterns

### Basic Fixture Access

```swift
import Testing
import SwiftFijos

@Test func loadFixture() throws {
    let url = try Fijos.getFixture("sample", extension: "json")
    let data = try Data(contentsOf: url)
    // use data...
}

@Test func discoverFixtures() throws {
    let allFixtures = try Fijos.listFixtures()
    let jsonFixtures = try Fijos.listFixtures(withExtension: "json")
    let matching = try Fijos.findFixtures(matching: "sample")
    let extensions = try Fijos.availableExtensions()
}
```

### Thread-Safe Access (Swift Testing)

When using Swift Testing with parallel test execution, use `FixtureManager` to prevent conflicts:

```swift
import Testing
import SwiftFijos

@Test func importDocument() async throws {
    // Automatically waits if another test is using this fixture
    let document = try await FixtureManager.shared.withExclusiveAccess(
        to: "test.json"
    ) { url in
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Document.self, from: data)
    }

    #expect(document != nil)
}
```

### Security-Scoped Resources (macOS)

For tests that need security-scoped resource access:

```swift
@Test func importScreenplay() async throws {
    let document = try await FixtureManager.shared.withSecurityScope(
        fixture: "test.fountain"
    ) { url in
        // url has security-scoped access started
        return try await DocumentImportService.importDocument(from: url)
        // access automatically stopped after block
    }

    #expect(document.elements.count > 0)
}
```

### Preloading Fixtures

For better test performance, preload fixtures once at test suite startup:

```swift
@Suite(.serialized)
@MainActor
struct MyTests {
    init() async throws {
        // Preload all fixtures into cache
        try await FixtureManager.shared.preloadAllFixtures()
    }

    @Test func test1() async throws {
        // Fixture already cached, instant access
        let url = try await FixtureManager.shared.withExclusiveAccess(
            to: "test.json"
        ) { $0 }
        // ...
    }
}
```

## Build and Test

**CRITICAL**: Use standard Swift build tools:

```bash
swift build
swift test
```

Or with Xcode:

```bash
xcodebuild -scheme SwiftFijos -destination 'platform=macOS,arch=arm64' build
xcodebuild -scheme SwiftFijos -destination 'platform=macOS,arch=arm64' test
```

## Design Patterns

- **Multi-strategy discovery**: Prioritizes CI environments, then bundles, then file system traversal
- **Actor-based locking**: `FixtureManager` is a global actor with `@Sendable` closures for thread safety
- **URL caching**: Avoids repeated discovery calls for better performance
- **Automatic lock release**: Uses `defer` to ensure locks are released even if operations throw
- **Waiting loop**: Tests wait 10ms between lock checks when fixture is locked
- **Security-scoped resources**: macOS-specific `#if os(macOS)` conditional for bookmark access
- **Statistics tracking**: Access counts for debugging parallel execution bottlenecks
- **Strict concurrency**: Swift 6 language mode with `StrictConcurrency` enabled

## Fixture Structure

The `Fixture` struct provides metadata for each discovered file:

- `id`: Full filename (e.g., "sample.json" or "README") -- used as `Identifiable` key
- `name`: Filename without extension (e.g., "sample" or "README")
- `fileExtension`: Extension without leading dot (e.g., "json" or "" for extensionless files)
- `url`: Full URL to the fixture file

Files are sorted alphabetically by `name` when listed. Symbolic links are excluded from listing (only regular files are returned).

## CI Environment Support

SwiftFijos detects and supports multiple CI environments:

- **Xcode Cloud**: `CI_PRIMARY_REPOSITORY_PATH`
- **GitHub Actions**: `GITHUB_ACTIONS`, `GITHUB_WORKSPACE`
- **GitLab CI**: `GITLAB_CI`, `CI_PROJECT_DIR`
- **CircleCI**: `CIRCLECI`, `CIRCLE_WORKING_DIRECTORY`
- **Jenkins**: `JENKINS_HOME`, `WORKSPACE`
- **Buildkite**: `BUILDKITE`, `BUILDKITE_BUILD_CHECKOUT_PATH`
- **Travis CI**: `TRAVIS`, `TRAVIS_BUILD_DIR`

The `isCI` property returns `true` if any of these environment variables are detected. The `ciRepositoryPath` property returns the repository path if available.

## Platform Requirements

**CRITICAL**: This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

**DO NOT lower the platform requirements to support older iOS/macOS versions.**

## Dependencies

SwiftFijos has zero external dependencies. It only uses Foundation framework APIs.

## Installation

Add SwiftFijos to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftFijos", from: "1.2.0")
]
```

Then add it as a dependency to your test target:

```swift
.testTarget(
    name: "YourPackageTests",
    dependencies: ["SwiftFijos"]
)
```

## Thread Safety

`FixtureManager` is a global actor that ensures thread-safe access to fixtures:

- **Exclusive locking**: Only one test can access a given fixture at a time
- **Automatic waiting**: If a fixture is locked, tests wait 10ms between checks until it's released
- **Lock release**: Locks are automatically released via `defer` even if operations throw
- **URL caching**: Thread-safe dictionary for cached fixture URLs
- **Statistics tracking**: Thread-safe access count dictionary

All public methods on `FixtureManager` are actor-isolated and async. Operation closures must be `@Sendable` to ensure thread safety across actor boundaries.

## Testing Best Practices

1. **Use `FixtureManager` for parallel tests**: If your tests run in parallel (Swift Testing default), always use `FixtureManager.shared.withExclusiveAccess` to prevent race conditions.

2. **Preload fixtures in suite init**: For better performance, preload all fixtures once at test suite startup rather than discovering them repeatedly.

3. **Use `withSecurityScope` for document access**: On macOS, if your code needs to access the fixture through security-scoped bookmarks (e.g., for document import services), use `withSecurityScope` instead of `withExclusiveAccess`.

4. **Add Fixtures to Copy Bundle Resources**: For bundled test execution (Xcode, Xcode Cloud), add the "Fixtures" directory to your test target's "Copy Bundle Resources" build phase.

5. **Check access statistics**: Use `printAccessReport()` to identify which fixtures are accessed most frequently and optimize caching strategies.

## Error Handling

All `FijosError` cases conform to `LocalizedError` and provide descriptive error messages:

- `fixturesDirectoryNotFound`: Fixtures directory could not be located using any discovery strategy
- `fixtureNotFound`: Specified fixture file does not exist in Fixtures directory
- `couldNotCreateTemporaryFixture`: Failed to create temporary fixture file
- `couldNotCreateDirectory`: Failed to create required directory
- `couldNotReadFile`: Failed to read file contents
- `couldNotWriteToFile`: Failed to write to file

Error messages include context about what was attempted and where the system searched.
