import Testing
import Foundation
@testable import SwiftFijos

@Suite("Fijos Tests")
struct SwiftFijosTests {

    // MARK: - Directory Access Tests

    @Test("Can access Fixtures directory")
    func testGetFixturesDirectory() throws {
        let fixturesDir = try Fijos.getFixturesDirectory()

        #expect(FileManager.default.fileExists(atPath: fixturesDir.path))
        #expect(fixturesDir.lastPathComponent == "Fixtures")
    }

    // MARK: - Single Fixture Retrieval Tests

    @Test("Can get fixture by name and extension")
    func testGetFixtureByNameAndExtension() throws {
        let fixtureURL = try Fijos.getFixture("bigfish", extension: "fountain")

        #expect(FileManager.default.fileExists(atPath: fixtureURL.path))
        #expect(fixtureURL.lastPathComponent == "bigfish.fountain")
    }

    @Test("Can read content from retrieved fixture")
    func testReadFixtureContent() throws {
        let fixtureURL = try Fijos.getFixture("test", extension: "fountain")
        let content = try String(contentsOf: fixtureURL, encoding: .utf8)

        #expect(!content.isEmpty)
    }

    @Test("Throws error for non-existent fixture")
    func testNonExistentFixture() {
        #expect(throws: FijosError.self) {
            _ = try Fijos.getFixture("nonexistent", extension: "xyz")
        }
    }

    // MARK: - List All Fixtures Tests

    @Test("Can list all fixtures")
    func testListAllFixtures() throws {
        let fixtures = try Fijos.listFixtures()

        #expect(fixtures.count >= 9, "Expected at least 9 fixtures")

        // Verify each fixture has required properties
        for fixture in fixtures {
            #expect(!fixture.id.isEmpty)
            #expect(!fixture.name.isEmpty)
            #expect(!fixture.fileExtension.isEmpty)
            #expect(FileManager.default.fileExists(atPath: fixture.url.path))
        }
    }

    @Test("All fixtures are accessible by path")
    func testAllFixturesAccessible() throws {
        let fixtures = try Fijos.listFixtures()

        for fixture in fixtures {
            let data = try Data(contentsOf: fixture.url)
            #expect(data.count > 0, "Fixture \(fixture.id) should have content")
        }
    }

    // MARK: - Filter by Extension Tests

    @Test("Can filter fixtures by extension - JSON")
    func testFilterJSONFixtures() throws {
        let jsonFixtures = try Fijos.listFixtures(withExtension: "json")

        #expect(jsonFixtures.count > 0, "Expected at least one JSON fixture")

        for fixture in jsonFixtures {
            #expect(fixture.fileExtension.lowercased() == "json")

            // Verify it's valid JSON by trying to parse
            let data = try Data(contentsOf: fixture.url)
            let json = try JSONSerialization.jsonObject(with: data)
            #expect(json is [String: Any] || json is [Any])
        }
    }

    @Test("Can filter fixtures by extension - Fountain")
    func testFilterFountainFixtures() throws {
        let fountainFixtures = try Fijos.listFixtures(withExtension: "fountain")

        #expect(fountainFixtures.count >= 2, "Expected at least 2 fountain fixtures")

        for fixture in fountainFixtures {
            #expect(fixture.fileExtension.lowercased() == "fountain")

            // Verify content can be read
            let content = try String(contentsOf: fixture.url, encoding: .utf8)
            #expect(!content.isEmpty)
        }
    }

    @Test("Can filter fixtures by extension - Highland")
    func testFilterHighlandFixtures() throws {
        let highlandFixtures = try Fijos.listFixtures(withExtension: "highland")

        #expect(highlandFixtures.count >= 1, "Expected at least 1 highland fixture")

        for fixture in highlandFixtures {
            #expect(fixture.fileExtension.lowercased() == "highland")
        }
    }

    @Test("Extension filter is case-insensitive")
    func testExtensionFilterCaseInsensitive() throws {
        let jsonLower = try Fijos.listFixtures(withExtension: "json")
        let jsonUpper = try Fijos.listFixtures(withExtension: "JSON")
        let jsonMixed = try Fijos.listFixtures(withExtension: "JsOn")

        #expect(jsonLower.count == jsonUpper.count)
        #expect(jsonLower.count == jsonMixed.count)
    }

    @Test("Extension filter handles leading dot")
    func testExtensionFilterWithDot() throws {
        let withDot = try Fijos.listFixtures(withExtension: ".json")
        let withoutDot = try Fijos.listFixtures(withExtension: "json")

        #expect(withDot.count == withoutDot.count)
    }

    // MARK: - Search by Pattern Tests

    @Test("Can search fixtures by name pattern")
    func testSearchByPattern() throws {
        let bigfishFixtures = try Fijos.findFixtures(matching: "bigfish")

        #expect(bigfishFixtures.count >= 3, "Expected at least 3 bigfish fixtures")

        for fixture in bigfishFixtures {
            #expect(fixture.name.lowercased().contains("bigfish"))
        }
    }

    @Test("Search is case-insensitive")
    func testSearchCaseInsensitive() throws {
        let lowerCase = try Fijos.findFixtures(matching: "test")
        let upperCase = try Fijos.findFixtures(matching: "TEST")
        let mixedCase = try Fijos.findFixtures(matching: "TeSt")

        #expect(lowerCase.count == upperCase.count)
        #expect(lowerCase.count == mixedCase.count)
    }

    @Test("Search with partial pattern")
    func testSearchPartialPattern() throws {
        let fixtures = try Fijos.findFixtures(matching: "fish")

        #expect(fixtures.count >= 3, "Expected at least 3 fixtures containing 'fish'")
    }

    // MARK: - Available Extensions Tests

    @Test("Can list all available extensions")
    func testAvailableExtensions() throws {
        let extensions = try Fijos.availableExtensions()

        #expect(extensions.count > 0, "Expected at least one extension")

        // Check for known extensions
        #expect(extensions.contains("json"), "Expected json extension")
        #expect(extensions.contains("fountain"), "Expected fountain extension")
        #expect(extensions.contains("highland"), "Expected highland extension")

        // Verify extensions are sorted
        #expect(extensions == extensions.sorted())

        // Verify no duplicates
        let uniqueExtensions = Set(extensions)
        #expect(extensions.count == uniqueExtensions.count)
    }

    // MARK: - Specific Fixture Tests

    @Test("Can access bigfish.fountain fixture")
    func testBigFishFountain() throws {
        let fixture = try Fijos.getFixture("bigfish", extension: "fountain")
        let content = try String(contentsOf: fixture, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fixture.path))
        #expect(!content.isEmpty)
        #expect(fixture.lastPathComponent == "bigfish.fountain")
    }

    @Test("Can access bigfish.fdx fixture")
    func testBigFishFDX() throws {
        let fixture = try Fijos.getFixture("bigfish", extension: "fdx")
        let data = try Data(contentsOf: fixture)

        #expect(FileManager.default.fileExists(atPath: fixture.path))
        #expect(data.count > 0)
    }

    @Test("Can access bigfish.highland fixture")
    func testBigFishHighland() throws {
        let fixture = try Fijos.getFixture("bigfish", extension: "highland")
        let data = try Data(contentsOf: fixture)

        #expect(FileManager.default.fileExists(atPath: fixture.path))
        #expect(data.count > 0)
    }


    @Test("Can access audio fixture")
    func testAudioFixture() throws {
        let fixture = try Fijos.getFixture(
            "000_action_Opening_visual_Calm_music_puppies_manicures_m-44k_2",
            extension: "aif"
        )
        let data = try Data(contentsOf: fixture)

        #expect(FileManager.default.fileExists(atPath: fixture.path))
        #expect(data.count > 0, "Audio file should have content")
    }

    @Test("Can access JSON fixtures")
    func testJSONFixtures() throws {
        let jsonNames = ["sample", "config"]

        for name in jsonNames {
            let fixture = try Fijos.getFixture(name, extension: "json")
            let data = try Data(contentsOf: fixture)

            #expect(FileManager.default.fileExists(atPath: fixture.path), "JSON fixture \(name).json should exist")
            #expect(data.count > 0, "JSON fixture \(name).json should have content")

            // Verify valid JSON
            let json = try JSONSerialization.jsonObject(with: data)
            #expect(json is [String: Any] || json is [Any], "JSON fixture \(name).json should be valid JSON")
        }
    }

    @Test("Can access XML fixture")
    func testXMLFixture() throws {
        let fixture = try Fijos.getFixture("data", extension: "xml")
        let content = try String(contentsOf: fixture, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fixture.path))
        #expect(!content.isEmpty)
        #expect(content.contains("<?xml"))
    }

    @Test("Can access text fixture")
    func testTextFixture() throws {
        let fixture = try Fijos.getFixture("notes", extension: "txt")
        let content = try String(contentsOf: fixture, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fixture.path))
        #expect(!content.isEmpty)
        #expect(content.contains("Test Notes"))
    }

    // MARK: - Fixture Metadata Tests

    @Test("Fixture ID matches filename")
    func testFixtureIDFormat() throws {
        let fixtures = try Fijos.listFixtures()

        for fixture in fixtures {
            let expectedID = "\(fixture.name).\(fixture.fileExtension)"
            #expect(fixture.id == expectedID)
        }
    }

    @Test("Fixture name excludes extension")
    func testFixtureNameFormat() throws {
        let fixture = try Fijos.listFixtures(withExtension: "fountain").first

        #expect(fixture != nil)
        if let fixture = fixture {
            #expect(!fixture.name.contains("."))
            #expect(fixture.fileExtension == "fountain")
        }
    }

    @Test("Fixtures are sorted by name")
    func testFixturesSorted() throws {
        let fixtures = try Fijos.listFixtures()
        let names = fixtures.map { $0.name }

        #expect(names == names.sorted())
    }

    // MARK: - CI Environment Tests

    @Test("isCI detects CI environment correctly")
    func testIsCIDetection() {
        let env = ProcessInfo.processInfo.environment
        let expectedCI = env["CI"] == "TRUE" ||
                        env["CI"] == "true" ||
                        env["GITHUB_ACTIONS"] != nil ||
                        env["CIRCLECI"] != nil ||
                        env["JENKINS_HOME"] != nil ||
                        env["BUILDKITE"] != nil ||
                        env["TRAVIS"] != nil ||
                        env["GITLAB_CI"] != nil

        #expect(Fijos.isCI == expectedCI)
    }

    @Test("isRunningTests returns true during test execution")
    func testIsRunningTestsDetection() {
        // This test is running, so isRunningTests should be true
        #expect(Fijos.isRunningTests == true)
    }

    @Test("ciRepositoryPath returns path when CI env vars are set")
    func testCIRepositoryPath() {
        let env = ProcessInfo.processInfo.environment
        let hasAnyPath = env["CI_PRIMARY_REPOSITORY_PATH"] != nil ||
                        env["GITHUB_WORKSPACE"] != nil ||
                        env["CI_PROJECT_DIR"] != nil ||
                        env["CIRCLE_WORKING_DIRECTORY"] != nil ||
                        env["WORKSPACE"] != nil ||
                        env["BUILDKITE_BUILD_CHECKOUT_PATH"] != nil ||
                        env["TRAVIS_BUILD_DIR"] != nil

        if hasAnyPath {
            #expect(Fijos.ciRepositoryPath != nil)
        } else {
            #expect(Fijos.ciRepositoryPath == nil)
        }
    }

    // MARK: - Integration Tests

    @Test("Can perform complete fixture workflow")
    func testCompleteWorkflow() throws {
        // 1. List all fixtures
        let allFixtures = try Fijos.listFixtures()
        #expect(allFixtures.count >= 9)

        // 2. Get available extensions
        let extensions = try Fijos.availableExtensions()
        #expect(extensions.count > 0)

        // 3. Filter by each extension
        for ext in extensions {
            let filtered = try Fijos.listFixtures(withExtension: ext)
            #expect(filtered.count > 0, "Expected fixtures with extension \(ext)")

            // 4. Read content from each filtered fixture
            for fixture in filtered {
                let data = try Data(contentsOf: fixture.url)
                #expect(data.count > 0)
            }
        }

        // 5. Search by pattern
        let searchResults = try Fijos.findFixtures(matching: "test")
        #expect(searchResults.count > 0)

        // 6. Get specific fixture
        let specific = try Fijos.getFixture("bigfish", extension: "fountain")
        #expect(FileManager.default.fileExists(atPath: specific.path))
    }

    @Test("All fixtures are discoverable")
    func testAllFixturesDiscoverable() throws {
        let fixtures = try Fijos.listFixtures()

        // We expect at least 10 fixture files (excluding directories)
        #expect(fixtures.count >= 10, "Expected at least 10 fixture files, found \(fixtures.count)")

        // Verify we can read each one
        for fixture in fixtures {
            let data = try Data(contentsOf: fixture.url)
            #expect(data.count > 0, "Fixture \(fixture.id) should be readable")
        }

        // Print summary
        print("✓ Found \(fixtures.count) fixtures")
        print("✓ Extensions: \(try Fijos.availableExtensions().joined(separator: ", "))")
    }
}
