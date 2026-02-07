# iOS UI Test Fixture Accessibility Patterns

> **Note**: This is a research/proposal document for features **not yet implemented** in SwiftFijos.
> The APIs described in "Proposed SwiftFijos API" are planned additions, not current functionality.

**Date**: 2026-01-01
**Context**: Research for adding reliable fixture copying to SwiftFijos for iOS UI testing

## Problem Statement

iOS UI tests face a unique challenge:
- **Test bundle** (`.xctest`) contains test code and resources
- **App sandbox** runs the target app with strict file system restrictions
- **No direct access**: App cannot read files from the test bundle

This creates a problem when:
1. Test code needs to pass fixture files to the app (e.g., via launch environment)
2. App tries to open those files (e.g., DocumentGroup, file import)
3. App gets "file not found" or permission errors

## Current SwiftFijos Implementation

### Fixture Discovery (Fijos.swift)
Searches for fixtures in this order:
1. CI environment variable (`CI_PRIMARY_REPOSITORY_PATH`)
2. Bundle resources (all accessible bundles)
3. File system traversal (fallback for local dev)

### Limitations for iOS UI Testing
- ✅ Works well for unit tests (same bundle as app/framework)
- ✅ Works well for CI environments
- ❌ **Doesn't solve UI test app accessibility** - app can't read test bundle resources

## iOS File System Access Patterns

### What the App CAN Access
1. **App Sandbox**:
   - `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)`
   - `FileManager.default.temporaryDirectory`
   - Limited to app's container

2. **Shared Container Groups** (requires entitlements):
   - `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.app")`
   - Requires configuration in both app and test target

3. **System Temporary Directory**:
   - `FileManager.default.temporaryDirectory`
   - Accessible by both test runner and app
   - **Most practical solution for UI tests**

### What the App CANNOT Access
- Test bundle resources
- Other app sandboxes
- System directories without entitlements

## Tested Approach: Temporary Directory

The `UITestHelpers.swift` implementation already uses this pattern:

```swift
private func copyFixtureToSharedLocation(_ sourceURL: URL, filename: String) -> URL {
    // Use the system's temporary directory which both test and app can access
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("io.intrusive-memory.Produciesta.UITests", isDirectory: true)

    // Create directory if needed
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let destinationURL = tempDir.appendingPathComponent(filename)

    // Remove existing file if present
    try? FileManager.default.removeItem(at: destinationURL)

    // Copy the file
    let content = try String(contentsOf: sourceURL, encoding: .utf8)
    try content.write(to: destinationURL, atomically: true, encoding: .utf8)

    return destinationURL
}
```

**Why this works:**
- Temporary directory is accessible to both test runner and app
- No entitlements required
- No security-scoped bookmarks needed
- Files persist for the duration of the test run
- Automatic cleanup on device restart

**Limitations:**
- Files are copied (disk space usage)
- Not suitable for very large files
- Temporary nature (not persistent)

## Proposed SwiftFijos API

### Goal
Make fixture copying for UI tests as simple as:

```swift
// In UI test
let app = XCUIApplication()
let fixtureURL = try Fijos.copyFixtureForUITesting("test.fountain")
app.launchEnvironment["TEST_FILE_PATH"] = fixtureURL.path
app.launch()
```

### Design Considerations

1. **Automatic Detection**: Should detect if running in UI test vs unit test
2. **Smart Copying**: Only copy when necessary (UI tests), return direct URL for unit tests
3. **Cleanup**: Provide mechanism to clean up temporary copies
4. **Error Handling**: Clear errors when copy fails

### Proposed Implementation

```swift
// In Fijos.swift

/// Copies a fixture to a location accessible to both UI test runner and target app.
///
/// For UI tests, fixtures in the test bundle are not accessible to the target app.
/// This method copies the fixture to the system temporary directory, which both
/// the test runner and app can access.
///
/// For unit tests and other contexts, returns the original fixture URL without copying.
///
/// - Parameters:
///   - named: The fixture filename (e.g., "test.fountain")
///   - appIdentifier: Reverse domain identifier for namespace (e.g., "com.example.app.UITests")
///   - from: The file path to start searching from. Defaults to `#filePath`.
/// - Returns: URL to the accessible fixture (either copied or original)
/// - Throws: `FijosError` if fixture not found or copy fails
///
/// ## Usage
///
/// ```swift
/// // UI Test
/// let app = XCUIApplication()
/// let fixtureURL = try Fijos.copyFixtureForUITesting(
///     "test.fountain",
///     appIdentifier: "com.example.app.UITests"
/// )
/// app.launchEnvironment["TEST_FILE_PATH"] = fixtureURL.path
/// app.launch()
/// ```
public static func copyFixtureForUITesting(
    _ named: String,
    appIdentifier: String,
    from path: String = #filePath
) throws -> URL {
    // Get original fixture
    let fixtureURL = try getFixture(named, from: path)

    // If not running UI tests, return original URL
    if !isRunningUITests {
        return fixtureURL
    }

    // Copy to shared temporary directory
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(appIdentifier, isDirectory: true)

    // Create directory
    try FileManager.default.createDirectory(
        at: tempDir,
        withIntermediateDirectories: true,
        attributes: nil
    )

    let destinationURL = tempDir.appendingPathComponent(named)

    // Remove existing
    try? FileManager.default.removeItem(at: destinationURL)

    // Copy file
    try FileManager.default.copyItem(at: fixtureURL, to: destinationURL)

    return destinationURL
}

/// Cleans up all fixtures copied for UI testing.
///
/// - Parameter appIdentifier: The app identifier used when copying fixtures
public static func cleanUITestFixtures(appIdentifier: String) throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(appIdentifier, isDirectory: true)

    try? FileManager.default.removeItem(at: tempDir)
}

/// Detects if currently running UI tests (XCUITest).
public static var isRunningUITests: Bool {
    // Check for XCUIApplication class
    if NSClassFromString("XCUIApplication") != nil {
        return true
    }
    // Check for UI test bundle
    if Bundle.allBundles.contains(where: {
        $0.bundlePath.contains("UITests.xctest") ||
        $0.bundlePath.contains("-Runner.app")
    }) {
        return true
    }
    return false
}
```

## Benefits of This Approach

1. **Simple API**: One method call to copy fixture
2. **Automatic Detection**: Smart enough to know when copying is needed
3. **Namespace Isolation**: App identifier prevents conflicts
4. **Standard Pattern**: Uses documented iOS temporary directory approach
5. **No Entitlements**: Works without app groups or special permissions
6. **Cleanup Support**: Provides method to clean up after tests

## Alternatives Considered

### App Groups
**Pros**: Persistent storage, official Apple mechanism
**Cons**: Requires entitlements configuration, more complex setup, not needed for ephemeral test data

### Security-Scoped Bookmarks
**Pros**: Works for user-selected files
**Cons**: Requires user interaction, complex API, overkill for test fixtures

### File Coordination
**Pros**: Thread-safe access
**Cons**: Adds complexity, not needed for single-threaded test execution

### Bundle Resource Copying at Build Time
**Pros**: No runtime copying needed
**Cons**: Increases app size, fixtures mixed with app resources, hard to maintain

## Implementation Plan

1. ✅ Research iOS file system patterns
2. ✅ Document patterns and proposed API
3. ⏳ Add `copyFixtureForUITesting()` to Fijos.swift
4. ⏳ Add `isRunningUITests` detection
5. ⏳ Add cleanup method
6. ⏳ Write tests
7. ⏳ Update UITestHelpers to use new Fijos API
8. ⏳ Document in SwiftFijos README

## References

- Apple Documentation: [File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/)
- Apple Documentation: [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- WWDC Session: [What's New in Testing](https://developer.apple.com/videos/play/wwdc2021/10192/)

## Notes

- Temporary directory is cleaned on device reboot, not after each test
- Consider adding `tearDown()` cleanup in test classes for immediate cleanup
- File copying is synchronous - may add latency to test setup for large files
- Works with all file types (binary and text)
