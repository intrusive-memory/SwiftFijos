# SwiftFijos

[![Tests](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml/badge.svg)](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml)

A lightweight Swift package for managing and discovering test fixtures in your Swift packages and projects.

## Overview

SwiftFijos provides a simple, reusable utility for loading fixture files in your test suites. It automatically locates your project's `Fixtures` directory (at the package root) and provides type-safe methods for retrieving and discovering fixture files by name, extension, or pattern matching.

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
    dependencies: [
        "YourPackage",
        "SwiftFijos"
    ]
)
```

## Usage

### Basic Setup

1. Create a `Fixtures` directory at the root of your package (same level as `Package.swift`)
2. Add your fixture files to this directory
3. Import `SwiftFijos` in your test files

### Examples

#### Loading a Specific Fixture

```swift
import XCTest
import SwiftFijos
@testable import YourPackage

final class YourTests: XCTestCase {
    func testLoadingFixture() throws {
        // Get a fixture file URL
        let fixtureURL = try Fijos.getFixture("sample", extension: "json")

        // Load and use the fixture
        let data = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        let result = try decoder.decode(YourType.self, from: data)

        // Your assertions here
        XCTAssertNotNil(result)
    }
}
```

#### Discovering Available Fixtures

```swift
func testDiscoverFixtures() throws {
    // List all fixtures
    let allFixtures = try Fijos.listFixtures()
    print("Found \(allFixtures.count) fixtures:")
    for fixture in allFixtures {
        print("  - \(fixture.name).\(fixture.fileExtension)")
    }

    // Find all JSON fixtures
    let jsonFixtures = try Fijos.listFixtures(withExtension: "json")
    XCTAssertFalse(jsonFixtures.isEmpty)

    // Search for fixtures by name pattern
    let bigFishFixtures = try Fijos.findFixtures(matching: "bigfish")
    XCTAssertGreaterThan(bigFishFixtures.count, 0)

    // Get all available file extensions
    let extensions = try Fijos.availableExtensions()
    print("Available extensions: \(extensions.joined(separator: ", "))")
}
```

#### Working with Fixture Metadata

```swift
func testFixtureMetadata() throws {
    let fixtures = try Fijos.listFixtures()

    for fixture in fixtures {
        print("ID: \(fixture.id)")
        print("Name: \(fixture.name)")
        print("Extension: \(fixture.fileExtension)")
        print("URL: \(fixture.url)")

        // Load the fixture data
        let data = try Data(contentsOf: fixture.url)
        print("Size: \(data.count) bytes\n")
    }
}
```

## API

### Fixture Type

```swift
public struct Fixture: Identifiable, Equatable {
    public let id: String              // "filename.ext"
    public let name: String            // filename without extension
    public let fileExtension: String   // file extension
    public let url: URL                // full URL to the fixture file
}
```

### Fijos Methods

#### Directory Access

##### `getFixturesDirectory(from testFilePath: String = #filePath) throws -> URL`
Returns the URL of the `Fixtures` directory at your project root. Searches upward from the test file location to find the project root using the following priority:
1. **Xcode projects**: Looks for `.xcodeproj` or `.xcworkspace` files (primary)
2. **SPM packages**: Looks for `Package.swift` file (secondary fallback)

This ensures that when used as a package dependency in an Xcode project, it finds the Xcode project's Fixtures directory rather than the package's.

**Parameters:**
- `testFilePath`: The file path to start searching from (defaults to the caller's file location via `#filePath`)

**Throws:** `FijosError.fixturesDirectoryNotFound` if the Fixtures directory doesn't exist.

#### Single Fixture Retrieval

##### `getFixture(_ name: String, extension: String, from: String = #filePath) throws -> URL`
Returns the URL for a specific fixture file.

**Parameters:**
- `name`: The name of the fixture file (without extension)
- `extension`: The file extension
- `from`: The file path to start searching from (defaults to caller's location via `#filePath`)

**Throws:** `FijosError.fixtureNotFound` if the fixture file doesn't exist.

##### `getFixture(_ filename: String, from: String = #filePath) throws -> URL`
Returns the URL for a specific fixture file by full filename.

**Parameters:**
- `filename`: The complete filename including extension (e.g., "test.json")
- `from`: The file path to start searching from (defaults to caller's location via `#filePath`)

**Throws:** `FijosError.fixtureNotFound` if the fixture file doesn't exist.

#### Discovery Methods

##### `listFixtures(from: String = #filePath) throws -> [Fixture]`
Returns all fixtures in the Fixtures directory, sorted by name.

**Parameters:**
- `from`: The file path to start searching from (defaults to caller's location via `#filePath`)

**Returns:** Array of `Fixture` objects representing all files in the Fixtures directory.

##### `listFixtures(withExtension: String, from: String = #filePath) throws -> [Fixture]`
Returns all fixtures with a specific file extension.

**Parameters:**
- `withExtension`: File extension to filter by (case-insensitive, with or without leading dot)
- `from`: The file path to start searching from (defaults to caller's location via `#filePath`)

**Returns:** Array of matching `Fixture` objects.

##### `findFixtures(matching: String, from: String = #filePath) throws -> [Fixture]`
Searches for fixtures whose names contain the specified pattern (case-insensitive).

**Parameters:**
- `matching`: Search pattern to match against fixture names
- `from`: The file path to start searching from (defaults to caller's location via `#filePath`)

**Returns:** Array of matching `Fixture` objects.

##### `availableExtensions(from: String = #filePath) throws -> [String]`
Returns all unique file extensions found in the Fixtures directory.

**Parameters:**
- `from`: The file path to start searching from (defaults to caller's location via `#filePath`)

**Returns:** Sorted array of file extensions (lowercase, without dots).

### Errors

```swift
enum FijosError: Error {
    case fixtureNotFound(String)
    case fixturesDirectoryNotFound(String)
}
```

## Project Structure

### For Xcode Projects

Place the `Fixtures` directory at the root of your Xcode project (same level as `.xcodeproj` or `.xcworkspace`):

```
YourApp/
├── YourApp.xcodeproj
├── Fixtures/              # Place your fixture files here
│   ├── sample.json
│   ├── test.xml
│   └── data.txt
├── YourApp/
│   └── (source files)
└── YourAppTests/
    └── (test files)
```

### For Swift Packages

Place the `Fixtures` directory at the root of your package (same level as `Package.swift`):

```
YourPackage/
├── Package.swift
├── Fixtures/              # Place your fixture files here
│   ├── sample.json
│   ├── test.xml
│   └── data.txt
├── Sources/
│   └── YourPackage/
└── Tests/
    └── YourPackageTests/
```

## How It Works

SwiftFijos automatically detects your environment and project type:

### CI Support

SwiftFijos supports multiple CI systems by checking for repository path environment variables:

| CI System | Environment Variable |
|-----------|---------------------|
| GitHub Actions | `GITHUB_WORKSPACE` |
| GitLab CI | `CI_PROJECT_DIR` |
| CircleCI | `CIRCLE_WORKING_DIRECTORY` |
| Jenkins | `WORKSPACE` |
| Buildkite | `BUILDKITE_BUILD_CHECKOUT_PATH` |
| Travis CI | `TRAVIS_BUILD_DIR` |
| Xcode Cloud | `CI_PRIMARY_REPOSITORY_PATH` |

#### Public API for CI Detection

```swift
// Check if running in any CI environment
if Fijos.isCI {
    print("Running in CI")
}

// Check if running within a test context
if Fijos.isRunningTests {
    print("Tests are executing")
}

// Get CI repository path (nil when not in CI or env var not set)
if let ciPath = Fijos.ciRepositoryPath {
    print("Repository at: \(ciPath)")
}
```

#### Note on Xcode Cloud

Xcode Cloud environment variables (`CI`, `CI_PRIMARY_REPOSITORY_PATH`, `CI_WORKSPACE`) are **only available during build scripts**, NOT at test runtime. This is a known limitation of Xcode Cloud. The library uses `#filePath` based discovery which works reliably in all environments including Xcode Cloud test runs.

### Local Development

For local development, SwiftFijos uses `#filePath` to find your project:

1. **`#filePath` Discovery**: Starts from the calling test file and searches upward
2. **Project Root Detection**: Looks for `.xcodeproj`, `.xcworkspace`, or `Package.swift`
3. **Recursive Search (Fallback)**: If no Fixtures folder is found at the project root, performs a recursive directory search

This means you always put your fixtures at your project root, regardless of how deep your test files are nested.

## License

Copyright (c) 2025

## Contributing

This package was refactored from SwiftScreenplay to be a reusable component across multiple projects.
