# SwiftFijos

[![Tests](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml/badge.svg)](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml)

A lightweight Swift package for managing and discovering test fixtures.

## Requirements

- Swift 6.2+
- macOS 26.0+ / iOS 26.0+

## Installation

Add SwiftFijos to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftFijos", from: "1.1.0")
]
```

Then add it as a dependency to your test target:

```swift
.testTarget(
    name: "YourPackageTests",
    dependencies: ["SwiftFijos"]
)
```

## Usage

1. Create a `Fixtures` directory at the root of your package
2. Add your fixture files to this directory
3. Import `SwiftFijos` in your test files

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

When using **Swift Testing** with parallel test execution, use `FixtureManager` to coordinate fixture access and prevent conflicts:

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

#### Security-Scoped Resources (macOS)

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

#### Preloading Fixtures

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

## API

### Fixture

```swift
public struct Fixture: Identifiable, Equatable {
    public let id: String           // Full filename (e.g., "sample.json")
    public let name: String         // Filename without extension
    public let fileExtension: String // Extension without dot (empty if none)
    public let url: URL             // Full URL to the file
}
```

### Fijos Methods

| Method | Description |
|--------|-------------|
| `getFixturesDirectory(from:)` | Returns URL to the Fixtures directory |
| `getFixture(_:from:)` | Get fixture by full filename |
| `getFixture(_:extension:from:)` | Get fixture by name and extension |
| `listFixtures(from:)` | List all fixtures (excludes symlinks) |
| `listFixtures(withExtension:from:)` | Filter fixtures by extension |
| `findFixtures(matching:from:)` | Search fixtures by name pattern |
| `availableExtensions(from:)` | List all unique extensions |

### FixtureManager Methods

| Method | Description |
|--------|-------------|
| `withExclusiveAccess(to:from:perform:)` | Access fixture with exclusive lock (waits if locked) |
| `withSecurityScope(fixture:from:perform:)` | Access fixture with security-scoped resource handling (macOS) |
| `isLocked(_:)` | Check if a fixture is currently locked |
| `releaseAllLocks()` | Release all locks (for cleanup) |
| `clearCache()` | Clear the fixture URL cache |
| `preloadFixtures(_:from:)` | Preload specific fixtures into cache |
| `preloadAllFixtures(from:)` | Preload all fixtures into cache |
| `getAccessCount(for:)` | Get access count for a fixture |
| `getAllAccessCounts()` | Get all access counts |
| `printAccessReport()` | Print formatted statistics report |
| `resetStatistics()` | Reset all access statistics |

### CI Detection

| Property | Description |
|----------|-------------|
| `isCI` | True if running in CI (GitHub Actions, GitLab, CircleCI, Jenkins, Buildkite, Travis) |
| `isRunningTests` | True if tests are executing (XCTest or Swift Testing) |
| `ciRepositoryPath` | CI repository path if available |

### Errors

```swift
public enum FijosError: Error {
    case fixturesDirectoryNotFound(String)
    case fixtureNotFound(String)
    case couldNotCreateTemporaryFixture(String)
    case couldNotCreateDirectory(String)
    case couldNotReadFile(String)
    case couldNotWriteToFile(String)
}
```

## Fixture Discovery

Discovery order:
1. `CI_PRIMARY_REPOSITORY_PATH` environment variable (Xcode Cloud)
2. Bundle resource search (bundled Fixtures directories)
3. File system traversal upward from `#filePath`

## License

Copyright (c) 2025
