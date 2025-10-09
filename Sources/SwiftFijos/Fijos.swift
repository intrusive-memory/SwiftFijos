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

    /// Returns the Fixtures directory URL from the calling project's root.
    /// Searches upward from the test file location to find the project root.
    /// Priority order: Xcode project (.xcodeproj or .xcworkspace), then Package.swift
    public static func getFixturesDirectory(from testFileURL: URL? = nil) throws -> URL {
        let startURL: URL

        if let testFileURL = testFileURL {
            startURL = testFileURL
        } else {
            // Use the caller's file path
            startURL = URL(fileURLWithPath: #filePath)
        }

        // Navigate up from the test file to find the project root
        var currentURL = startURL.deletingLastPathComponent()
        var searchDepth = 0
        let maxSearchDepth = 10

        while searchDepth < maxSearchDepth {
            let fixturesURL = currentURL.appendingPathComponent("Fixtures")

            // Check if Fixtures directory exists at this level
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fixturesURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                // Verify this is a valid root by checking for project markers
                if hasProjectRoot(at: currentURL) {
                    return fixturesURL
                }
            }

            // Check if we've hit a project root marker
            if hasProjectRoot(at: currentURL) {
                // We found a project root, check for Fixtures here
                if FileManager.default.fileExists(atPath: fixturesURL.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    return fixturesURL
                } else {
                    throw FijosError.fixturesDirectoryNotFound(
                        "Fixtures directory not found at project root: \(fixturesURL.path). " +
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
