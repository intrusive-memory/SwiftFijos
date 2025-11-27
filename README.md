# SwiftFijos

[![Tests](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml/badge.svg)](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml)

A lightweight Swift package for managing and discovering test fixtures.

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
