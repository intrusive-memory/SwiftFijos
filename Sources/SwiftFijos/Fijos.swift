import Foundation

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
    /// - Parameter from: The file path to start searching from for the fallback strategy. Defaults to `#file`.
    /// - Returns: A `URL` pointing to the "Fixtures" directory.
    /// - Throws: `FijosError.fixturesDirectoryNotFound` if the directory cannot be located using any of the strategies.
    public static func getFixturesDirectory(from path: String = #file) throws -> URL {
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
    ///   - from: The file path to start the search for the "Fixtures" directory. Defaults to `#file`.
    /// - Returns: The `URL` of the found fixture file.
    /// - Throws: `FijosError.fixtureNotFound` if the file doesn't exist in the "Fixtures" directory.
    public static func getFixture(_ named: String, from path: String = #file) throws -> URL {
        let fixturesURL = try getFixturesDirectory(from: path)
        let fileURL = fixturesURL.appendingPathComponent(named)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            throw FijosError.fixtureNotFound("Fixture '\(named)' not found in \(fixturesURL.path)")
        }
    }
}
