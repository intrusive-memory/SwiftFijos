import Foundation

/// Represents a fixture file with its metadata.
public struct Fixture: Identifiable, Equatable {
    /// Unique identifier - the full filename (e.g., "sample.json" or "README")
    public let id: String
    /// The file name without extension
    public let name: String
    /// The file extension without the leading dot (empty string if no extension)
    public let fileExtension: String
    /// The full URL to the fixture file
    public let url: URL

    public init(url: URL) {
        self.url = url
        self.id = url.lastPathComponent
        self.fileExtension = url.pathExtension
        self.name = url.deletingPathExtension().lastPathComponent
    }
}

public enum FijosError: Error, LocalizedError {
    case fixturesDirectoryNotFound(String)
    case fixtureNotFound(String)
    case couldNotCreateTemporaryFixture(String)
    case couldNotCreateDirectory(String)
    case couldNotReadFile(String)
    case couldNotWriteToFile(String)

    public var errorDescription: String? {
        switch self {
        case .fixturesDirectoryNotFound(let message):
            return "Fixtures directory not found: \(message)"
        case .fixtureNotFound(let message):
            return "Fixture not found: \(message)"
        case .couldNotCreateTemporaryFixture(let message):
            return "Could not create temporary fixture: \(message)"
        case .couldNotCreateDirectory(let message):
            return "Could not create directory: \(message)"
        case .couldNotReadFile(let message):
            return "Could not read file: \(message)"
        case .couldNotWriteToFile(let message):
            return "Could not write to file: \(message)"
        }
    }
}

public class Fijos {

    /// Searches for a directory named "Fixtures" using multiple strategies to support both local development and CI environments.
    ///
    /// The search strategies are executed in this order:
    /// 1.  **CI Environment Variable:** It checks for the `CI_PRIMARY_REPOSITORY_PATH` environment variable, which is set by Xcode Cloud, and constructs a path to the "Fixtures" directory from there.
    /// 2.  **Bundle Search:** It looks for a "Fixtures" directory inside the resources of all accessible bundles. This is the preferred method for tests running from a bundle (e.g., in Xcode or Xcode Cloud). For this to work, you must add the "Fixtures" folder to your test target's "Copy Bundle Resources" build phase.
    /// 3.  **File System Traversal (Fallback):** As a fallback for local development, it traverses up the directory tree from the source file's location (`#file`) to find the "Fixtures" directory.
    ///
    /// - Parameter from: The file path to start searching from for the fallback strategy. Defaults to `#filePath`.
    /// - Returns: A `URL` pointing to the "Fixtures" directory.
    /// - Throws: `FijosError.fixturesDirectoryNotFound` if the directory cannot be located using any of the strategies.
    public static func getFixturesDirectory(from path: String = #filePath) throws -> URL {
        // 1. CI Environment Variable (Xcode Cloud)
        if let repoPath = ProcessInfo.processInfo.environment["CI_PRIMARY_REPOSITORY_PATH"] {
            let fixturesURL = URL(fileURLWithPath: repoPath).appendingPathComponent("Fixtures")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fixturesURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return fixturesURL
            }
        }

        // 2. Bundle Search
        for bundle in Bundle.allBundles {
            // This finds a "Fixtures" directory copied as a resource.
            if let fixturesURL = bundle.url(forResource: "Fixtures", withExtension: nil) {
                 var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fixturesURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return fixturesURL
                }
            }
        }

        // 3. File System Traversal (Fallback for local development)
        var currentURL = URL(fileURLWithPath: path)
        for _ in 0..<10 {
            currentURL = currentURL.deletingLastPathComponent()
            let fixturesURL = currentURL.appendingPathComponent("Fixtures")

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fixturesURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return fixturesURL
            }
        }

        throw FijosError.fixturesDirectoryNotFound(
            "Could not locate Fixtures directory. Searched CI environment variables, test bundles, and by traversing up from \(path). Ensure the 'Fixtures' directory is added to the test target's 'Copy Bundle Resources' build phase."
        )
    }

    /// Provides a URL for a fixture file.
    ///
    /// This function locates the "Fixtures" directory using `getFixturesDirectory` and then
    /// finds the specified file within it.
    ///
    /// - Parameters:
    ///   - named: The name of the fixture file (e.g., "document.json").
    ///   - from: The file path to start the search for the "Fixtures" directory. Defaults to `#filePath`.
    /// - Returns: The `URL` of the found fixture file.
    /// - Throws: `FijosError.fixtureNotFound` if the file doesn't exist in the "Fixtures" directory.
    public static func getFixture(_ named: String, from path: String = #filePath) throws -> URL {
        let fixturesURL = try getFixturesDirectory(from: path)
        let fileURL = fixturesURL.appendingPathComponent(named)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            throw FijosError.fixtureNotFound("Fixture '\(named)' not found in \(fixturesURL.path)")
        }
    }

    /// Provides a URL for a fixture file with separate name and extension.
    ///
    /// - Parameters:
    ///   - name: The name of the fixture file without extension (e.g., "document").
    ///   - extension: The file extension without the leading dot (e.g., "json").
    ///   - from: The file path to start the search for the "Fixtures" directory. Defaults to `#filePath`.
    /// - Returns: The `URL` of the found fixture file.
    /// - Throws: `FijosError.fixtureNotFound` if the file doesn't exist in the "Fixtures" directory.
    public static func getFixture(_ name: String, extension ext: String, from path: String = #filePath) throws -> URL {
        let filename = "\(name).\(ext)"
        return try getFixture(filename, from: path)
    }

    /// Lists all fixture files in the Fixtures directory.
    ///
    /// - Parameter from: The file path to start the search for the "Fixtures" directory. Defaults to `#filePath`.
    /// - Returns: An array of `Fixture` objects sorted by name.
    /// - Throws: `FijosError.fixturesDirectoryNotFound` if the Fixtures directory cannot be located.
    /// - Note: Symbolic links are excluded; only regular files are returned.
    public static func listFixtures(from path: String = #filePath) throws -> [Fixture] {
        let fixturesURL = try getFixturesDirectory(from: path)
        let contents = try FileManager.default.contentsOfDirectory(
            at: fixturesURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return contents
            .compactMap { url -> Fixture? in
                guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true else {
                    return nil
                }
                return Fixture(url: url)
            }
            .sorted { $0.name < $1.name }
    }

    /// Lists fixture files filtered by extension.
    ///
    /// - Parameters:
    ///   - extension: The file extension to filter by (with or without leading dot).
    ///   - from: The file path to start the search for the "Fixtures" directory. Defaults to `#filePath`.
    /// - Returns: An array of `Fixture` objects with the specified extension, sorted by name.
    /// - Throws: `FijosError.fixturesDirectoryNotFound` if the Fixtures directory cannot be located.
    public static func listFixtures(withExtension ext: String, from path: String = #filePath) throws -> [Fixture] {
        let normalizedExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        return try listFixtures(from: path).filter {
            $0.fileExtension.lowercased() == normalizedExt.lowercased()
        }
    }

    /// Finds fixtures matching a name pattern (case-insensitive).
    ///
    /// - Parameters:
    ///   - pattern: The pattern to search for in fixture names.
    ///   - from: The file path to start the search for the "Fixtures" directory. Defaults to `#filePath`.
    /// - Returns: An array of `Fixture` objects whose names contain the pattern, sorted by name.
    /// - Throws: `FijosError.fixturesDirectoryNotFound` if the Fixtures directory cannot be located.
    public static func findFixtures(matching pattern: String, from path: String = #filePath) throws -> [Fixture] {
        let lowercasedPattern = pattern.lowercased()
        return try listFixtures(from: path).filter {
            $0.name.lowercased().contains(lowercasedPattern)
        }
    }

    /// Returns all unique file extensions present in the Fixtures directory, sorted alphabetically.
    ///
    /// - Parameter from: The file path to start the search for the "Fixtures" directory. Defaults to `#filePath`.
    /// - Returns: A sorted array of unique file extensions (without leading dots).
    /// - Throws: `FijosError.fixturesDirectoryNotFound` if the Fixtures directory cannot be located.
    public static func availableExtensions(from path: String = #filePath) throws -> [String] {
        let fixtures = try listFixtures(from: path)
        let extensions = Set(fixtures.map { $0.fileExtension.lowercased() })
        return extensions.sorted()
    }

    // MARK: - CI Environment Detection

    /// Indicates whether the code is running in a CI environment.
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

    /// Indicates whether tests are currently running.
    public static var isRunningTests: Bool {
        // XCTest detection
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if NSClassFromString("XCTestCase") != nil {
            return true
        }
        // Swift Testing framework detection
        if NSClassFromString("Testing.Test") != nil {
            return true
        }
        // Check for test bundles
        if Bundle.allBundles.contains(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            return true
        }
        // Check for swift-testing runner
        if ProcessInfo.processInfo.arguments.contains(where: { $0.contains("swift-testing") || $0.contains("xctest") }) {
            return true
        }
        return false
    }

    /// Returns the CI repository path if running in a CI environment, nil otherwise.
    public static var ciRepositoryPath: String? {
        let env = ProcessInfo.processInfo.environment
        return env["CI_PRIMARY_REPOSITORY_PATH"] ??
               env["GITHUB_WORKSPACE"] ??
               env["CI_PROJECT_DIR"] ??
               env["CIRCLE_WORKING_DIRECTORY"] ??
               env["WORKSPACE"] ??
               env["BUILDKITE_BUILD_CHECKOUT_PATH"] ??
               env["TRAVIS_BUILD_DIR"]
    }
}
