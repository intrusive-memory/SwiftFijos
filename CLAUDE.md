# SwiftFijos - Claude Code Instructions

## Project Overview

SwiftFijos is a Swift package for managing and discovering test fixture files in Swift packages and Xcode projects. It provides automatic detection of Xcode Cloud CI environments and intelligent fixture directory discovery.

## Key Features

- Automatic Xcode Cloud CI environment detection
- Case-insensitive fixture directory discovery
- Recursive directory search fallback
- Support for both Xcode projects and Swift packages

## Xcode Cloud Environment Variables

Reference: https://developer.apple.com/documentation/xcode/environment-variable-reference

### Key Variables Used by This Library

| Variable | Description |
|----------|-------------|
| `CI` | Set to `"TRUE"` when running in Xcode Cloud |
| `CI_PRIMARY_REPOSITORY_PATH` | Path to the cloned repository root |
| `CI_WORKSPACE` | Path to the workspace directory |

### Additional Xcode Cloud Variables (for reference)

| Variable | Description |
|----------|-------------|
| `CI_BUILD_ID` | Unique identifier for current build |
| `CI_BUILD_NUMBER` | Build number |
| `CI_BUNDLE_ID` | Product bundle identifier |
| `CI_PRODUCT_PLATFORM` | Platform type (iOS, macOS, tvOS, watchOS) |
| `CI_XCODE_SCHEME` | Scheme used in current action |
| `CI_BRANCH` | Source branch name |
| `CI_COMMIT` | Current commit SHA |
| `CI_TAG` | Git tag name (if applicable) |
| `CI_PULL_REQUEST_NUMBER` | Pull request identifier (if applicable) |
| `CI_XCODEBUILD_ACTION` | Action type (e.g., 'archive', 'test') |
| `CI_ARCHIVE_PATH` | Path to the exported app archive |
| `CI_RESULT_BUNDLE_PATH` | Path to the test action's result bundle |
| `CI_TEST_DESTINATION_DEVICE_TYPE` | Test device type |
| `CI_TEST_DESTINATION_RUNTIME` | OS version for simulated device |

## Development Commands

```bash
# Build the package
swift build

# Run tests
swift test

# Run tests with code coverage
swift test --enable-code-coverage
```

## Architecture

- `Sources/SwiftFijos/Fijos.swift` - Main implementation
- `Tests/SwiftFijosTests/FijosTests.swift` - Test suite
- `Fixtures/` - Test fixture files

## Fixture Discovery Priority

1. **Xcode Cloud**: Uses `CI_PRIMARY_REPOSITORY_PATH`, then `CI_WORKSPACE`
2. **Local Xcode Projects**: Searches for `.xcodeproj` or `.xcworkspace`
3. **Swift Packages**: Searches for `Package.swift`
4. **Fallback**: Recursive directory search using `FileManager.enumerator`
