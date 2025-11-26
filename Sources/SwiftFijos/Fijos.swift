//
//  Fijos.swift
//  SwiftFijos
//
//  Copyright (c) 2025
//
//  Helper for loading fixture files in tests

import Foundation

/// Represents a fixture file with metadata
public struct Fixture: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let fileExtension: String
    public let url: URL

    public init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.fileExtension = url.pathExtension
        self.id = "\(name).\(fileExtension)"
    }
}

public enum Fijos {
    public enum FijosError: Error {
        case fixtureNotFound(String)
        case fixturesDirectoryNotFound(String)
    }

    // MARK: - CI Environment Detection
    // Note: Xcode Cloud environment variables (CI, CI_PRIMARY_REPOSITORY_PATH, CI_WORKSPACE)
    // are only available during build scripts, NOT at test runtime.
    // For test runtime detection, we use alternative methods.
    // Reference: https://developer.apple.com/documentation/xcode/environment-variable-reference

    /// Checks if running in a CI environment
    ///
    /// Detection priority:
    /// 1. `CI` environment variable (works in build scripts and some CI systems)
    /// 2. `GITHUB_ACTIONS` environment variable (GitHub Actions)
    /// 3. `CIRCLECI` environment variable (CircleCI)
    /// 4. `JENKINS_HOME` environment variable (Jenkins)
    /// 5. `BUILDKITE` environment variable (Buildkite)
    /// 6. `TRAVIS` environment variable (Travis CI)
    /// 7. `GITLAB_CI` environment variable (GitLab CI)
    ///
    /// Note: In Xcode Cloud, the `CI` variable is set to "TRUE" but may not be
    /// available at test runtime. Use `isRunningTests` for test-specific detection.
    public static var isCI: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["CI"] == "TRUE" ||
               env["CI"] == "true" ||
               env["GITHUB_ACTIONS"] != nil ||
               env["CIRCLECI"] != nil ||
               env["JENKINS_HOME"] != nil ||
               env["BUILDKITE"] != nil ||
               env["TRAVIS"] != nil ||
               env["GITLAB_CI"] != nil
    }

    /// Checks if running in Xcode Cloud CI environment (build scripts only)
    ///
    /// - Important: This only works reliably in custom build scripts (ci_pre_xcodebuild.sh, etc.),
    ///   NOT at test runtime. Xcode Cloud environment variables are not passed to the test runner.
    ///   For test runtime, rely on `#filePath` based discovery instead.
    @available(*, deprecated, message: "Xcode Cloud env vars are not available at test runtime. Use #filePath based discovery.")
    public static var isXcodeCloud: Bool {
        ProcessInfo.processInfo.environment["CI"] == "TRUE"
    }

    /// Checks if code is currently running within a test context
    ///
    /// Uses multiple detection methods for reliability across different test runners:
    /// 1. Process name check (xctest, swiftpm-testing-helper)
    /// 2. XCTest class availability check
    /// 3. XCTestConfigurationFilePath environment variable
    public static var isRunningTests: Bool {
        let processName = ProcessInfo.processInfo.processName
        // Check if process name indicates test runner
        // - "xctest": Xcode test runner
        // - "swiftpm-testing-helper": Swift Testing with `swift test`
        // - Suffix "PackageTests": Package test bundle
        if processName == "xctest" ||
           processName == "swiftpm-testing-helper" ||
           processName.hasSuffix("PackageTests") {
            return true
        }
        // Check if XCTest framework is loaded (runtime check)
        if NSClassFromString("XCTest") != nil {
            return true
        }
        // Check for XCTest configuration file path (set by xcodebuild)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        // Check for XCTestSessionIdentifier (set during test sessions)
        if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil {
            return true
        }
        return false
    }

    /// Returns the primary repository path when running in Xcode Cloud
    ///
    /// - Important: This is only available in custom build scripts, NOT at test runtime.
    @available(*, deprecated, message: "Xcode Cloud env vars are not available at test runtime. Use #filePath based discovery.")
    public static var xcodeCloudRepositoryPath: URL? {
        guard let path = ProcessInfo.processInfo.environment["CI_PRIMARY_REPOSITORY_PATH"] else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    /// Returns the workspace path when running in Xcode Cloud
    ///
    /// - Important: This is only available in custom build scripts, NOT at test runtime.
    @available(*, deprecated, message: "Xcode Cloud env vars are not available at test runtime. Use #filePath based discovery.")
    public static var xcodeCloudWorkspacePath: URL? {
        guard let path = ProcessInfo.processInfo.environment["CI_WORKSPACE"] else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    /// Returns a CI repository path if available from any supported CI system
    ///
    /// Checks environment variables from multiple CI systems:
    /// - Xcode Cloud: `CI_PRIMARY_REPOSITORY_PATH`
    /// - GitHub Actions: `GITHUB_WORKSPACE`
    /// - GitLab CI: `CI_PROJECT_DIR`
    /// - CircleCI: `CIRCLE_WORKING_DIRECTORY`
    /// - Jenkins: `WORKSPACE`
    /// - Buildkite: `BUILDKITE_BUILD_CHECKOUT_PATH`
    /// - Travis CI: `TRAVIS_BUILD_DIR`
    public static var ciRepositoryPath: URL? {
        let env = ProcessInfo.processInfo.environment
        let pathVars = [
            "CI_PRIMARY_REPOSITORY_PATH",  // Xcode Cloud
            "GITHUB_WORKSPACE",            // GitHub Actions
            "CI_PROJECT_DIR",              // GitLab CI
            "CIRCLE_WORKING_DIRECTORY",    // CircleCI
            "WORKSPACE",                   // Jenkins
            "BUILDKITE_BUILD_CHECKOUT_PATH", // Buildkite
            "TRAVIS_BUILD_DIR"             // Travis CI
        ]

        for varName in pathVars {
            if let path = env[varName], !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Returns the Fixtures directory URL from the calling project's root.
    ///
    /// Discovery priority:
    /// 1. CI repository path (if available from any supported CI system)
    /// 2. `#filePath` based discovery - searches upward to find project root
    ///
    /// Project root detection looks for:
    /// - Xcode projects: `.xcodeproj` or `.xcworkspace` files
    /// - Swift packages: `Package.swift` file
    ///
    /// If no Fixtures directory is found at the expected location, performs a recursive
    /// directory search from the project root to find a Fixtures folder.
    ///
    /// - Parameter testFilePath: The file path to start searching from. Defaults to the caller's file location.
    public static func getFixturesDirectory(from testFilePath: String = #filePath) throws -> URL {
        // Try CI repository path first (works across multiple CI systems)
        if let ciPath = ciRepositoryPath {
            if let fixturesURL = findDirectory(named: "Fixtures", in: ciPath) {
                return fixturesURL
            }
            // Fallback: search recursively for Fixtures directory
            if let fixturesURL = searchForFixturesDirectory(from: ciPath) {
                return fixturesURL
            }
        }

        // Use the caller's file path (evaluated at call site, not definition site)
        let startURL = URL(fileURLWithPath: testFilePath)

        // Navigate up from the test file to find the project root
        var currentURL = startURL.deletingLastPathComponent()
        var searchDepth = 0
        let maxSearchDepth = 10

        while searchDepth < maxSearchDepth {
            // Check if Fixtures directory exists at this level (case-insensitive)
            if let fixturesURL = findDirectory(named: "Fixtures", in: currentURL) {
                // Verify this is a valid root by checking for project markers
                if hasProjectRoot(at: currentURL) {
                    return fixturesURL
                }
            }

            // Check if we've hit a project root marker
            if hasProjectRoot(at: currentURL) {
                // We found a project root, check for Fixtures here
                if let fixturesURL = findDirectory(named: "Fixtures", in: currentURL) {
                    return fixturesURL
                } else {
                    // Fallback: search recursively for Fixtures directory
                    if let fixturesURL = searchForFixturesDirectory(from: currentURL) {
                        return fixturesURL
                    }
                    throw FijosError.fixturesDirectoryNotFound(
                        "Fixtures directory not found at project root: \(currentURL.path). " +
                        "Please create a 'Fixtures' directory at your project root."
                    )
                }
            }

            // Move up one directory
            currentURL = currentURL.deletingLastPathComponent()
            searchDepth += 1
        }

        throw FijosError.fixturesDirectoryNotFound(
            "Could not locate Fixtures directory or project root after searching \(maxSearchDepth) levels up from \(startURL.path)"
        )
    }

    /// Recursively searches for a Fixtures directory starting from the given root URL
    /// Uses FileManager.enumerator for efficient directory traversal
    /// - Parameter rootURL: The root directory to start searching from
    /// - Returns: The URL of the Fixtures directory if found, nil otherwise
    private static func searchForFixturesDirectory(from rootURL: URL) -> URL? {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true } // Continue on errors
        ) else {
            return nil
        }

        while let fileURL = enumerator.nextObject() as? URL {
            // Check if it's a directory
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else {
                continue
            }

            // Case-insensitive check for "Fixtures" directory
            if fileURL.lastPathComponent.lowercased() == "fixtures" {
                return fileURL
            }

            // Skip deep traversal into certain directories
            let skipDirectories = [".build", "DerivedData", "Pods", "Carthage", "node_modules", ".git"]
            if skipDirectories.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
            }
        }

        return nil
    }

    /// Finds a directory with a case-insensitive name match in the given parent directory.
    /// - Parameters:
    ///   - name: The directory name to search for (case-insensitive)
    ///   - parentURL: The parent directory to search in
    /// - Returns: The URL of the matching directory, or nil if not found
    private static func findDirectory(named name: String, in parentURL: URL) -> URL? {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                // Check if it's a directory
                if let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey]),
                   resourceValues.isDirectory == true {
                    // Case-insensitive name comparison
                    if item.lastPathComponent.lowercased() == name.lowercased() {
                        return item
                    }
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Checks if the given directory contains project root markers.
    /// Priority: .xcodeproj or .xcworkspace (Xcode projects), then Package.swift (SPM packages)
    private static func hasProjectRoot(at url: URL) -> Bool {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            // First priority: Check for Xcode project files
            for item in contents {
                let filename = item.lastPathComponent
                if filename.hasSuffix(".xcodeproj") || filename.hasSuffix(".xcworkspace") {
                    return true
                }
            }

            // Second priority: Check for Package.swift
            let packageSwiftURL = url.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageSwiftURL.path) {
                return true
            }
        } catch {
            return false
        }

        return false
    }

    /// Returns the URL for a specific fixture file by filename only
    /// - Parameter filename: The complete filename including extension (e.g., "test.fountain")
    /// - Returns: URL to the fixture file
    /// - Throws: FijosError if the fixture is not found
    public static func getFixture(_ filename: String) throws -> URL {
        let fixturesDirectory = try getFixturesDirectory()
        let fixtureURL = fixturesDirectory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw FijosError.fixtureNotFound("Fixture \(filename) not found at \(fixtureURL.path)")
        }

        return fixtureURL
    }

    /// Returns the URL for a specific fixture file
    public static func getFixture(_ name: String, extension ext: String) throws -> URL {
        let fixturesDirectory = try getFixturesDirectory()
        let fixtureURL = fixturesDirectory.appendingPathComponent("\(name).\(ext)")

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw FijosError.fixtureNotFound("Fixture \(name).\(ext) not found at \(fixtureURL.path)")
        }

        return fixtureURL
    }

    /// Lists all fixtures in the Fixtures directory
    public static func listFixtures() throws -> [Fixture] {
        let fixturesDirectory = try getFixturesDirectory()
        let fileManager = FileManager.default

        let contents = try fileManager.contentsOfDirectory(
            at: fixturesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return contents
            .filter { url in
                // Only include regular files, not directories
                (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            }
            .map { Fixture(url: $0) }
            .sorted { $0.name < $1.name }
    }

    /// Lists all fixtures with a specific file extension
    public static func listFixtures(withExtension ext: String) throws -> [Fixture] {
        let allFixtures = try listFixtures()
        let normalizedExtension = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))

        return allFixtures.filter { fixture in
            fixture.fileExtension.lowercased() == normalizedExtension
        }
    }

    /// Searches for fixtures matching a name pattern (case-insensitive)
    public static func findFixtures(matching pattern: String) throws -> [Fixture] {
        let allFixtures = try listFixtures()
        let lowercasePattern = pattern.lowercased()

        return allFixtures.filter { fixture in
            fixture.name.lowercased().contains(lowercasePattern)
        }
    }

    /// Returns all unique file extensions found in the Fixtures directory
    public static func availableExtensions() throws -> [String] {
        let fixtures = try listFixtures()
        let extensions = Set(fixtures.map { $0.fileExtension.lowercased() })
        return Array(extensions).sorted()
    }
}
