# SwiftFijos

[![Tests](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml/badge.svg)](https://github.com/intrusive-memory/SwiftFijos/actions/workflows/tests.yml)

A lightweight Swift package for managing and discovering test fixtures in your Swift packages and projects.

## Overview

SwiftFijos provides a simple, reusable utility for loading fixture files in your test suites. It automatically locates your project's `Fixtures` directory (at the package root) and provides type-safe methods for retrieving and discovering fixture files by name, extension, or pattern matching.

## Installation

Add SwiftFijos to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftFijos", from: "1.0.0")
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

##### `getFixturesDirectory(from: URL? = nil) throws -> URL`
Returns the URL of the `Fixtures` directory at your project root. Searches upward from the test file location to find the project root using the following priority:
1. **Xcode projects**: Looks for `.xcodeproj` or `.xcworkspace` files (primary)
2. **SPM packages**: Looks for `Package.swift` file (secondary fallback)

This ensures that when used as a package dependency in an Xcode project, it finds the Xcode project's Fixtures directory rather than the package's.

**Parameters:**
- `from`: Optional URL to start searching from (defaults to using `#filePath`)

**Throws:** `FijosError.fixturesDirectoryNotFound` if the Fixtures directory doesn't exist.

#### Single Fixture Retrieval

##### `getFixture(_ name: String, extension: String) throws -> URL`
Returns the URL for a specific fixture file.

**Parameters:**
- `name`: The name of the fixture file (without extension)
- `extension`: The file extension

**Throws:** `FijosError.fixtureNotFound` if the fixture file doesn't exist.

#### Discovery Methods

##### `listFixtures() throws -> [Fixture]`
Returns all fixtures in the Fixtures directory, sorted by name.

**Returns:** Array of `Fixture` objects representing all files in the Fixtures directory.

##### `listFixtures(withExtension: String) throws -> [Fixture]`
Returns all fixtures with a specific file extension.

**Parameters:**
- `withExtension`: File extension to filter by (case-insensitive, with or without leading dot)

**Returns:** Array of matching `Fixture` objects.

##### `findFixtures(matching: String) throws -> [Fixture]`
Searches for fixtures whose names contain the specified pattern (case-insensitive).

**Parameters:**
- `matching`: Search pattern to match against fixture names

**Returns:** Array of matching `Fixture` objects.

##### `availableExtensions() throws -> [String]`
Returns all unique file extensions found in the Fixtures directory.

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

SwiftFijos automatically detects your project type:

1. **Xcode Projects (Priority)**: When included as a dependency in an Xcode project, it searches for `.xcodeproj` or `.xcworkspace` files to identify the project root, then looks for the `Fixtures` directory there.

2. **Swift Packages (Fallback)**: If no Xcode project is found, it searches for `Package.swift` to identify the package root, then looks for the `Fixtures` directory there.

This means you always put your fixtures at your project root, regardless of how deep your test files are nested.

## License

Copyright (c) 2025

## Contributing

This package was refactored from SwiftScreenplay to be a reusable component across multiple projects.
