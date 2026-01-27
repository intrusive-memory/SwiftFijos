# Changelog

All notable changes to SwiftFijos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- **Project Icon** - Added icon.jpg and SwiftFijos.png

### Changed

- **CI/CD Updates** - Disabled iOS tests
  - Only macOS unit tests run on PRs
  - Branch protection updated to match

- **Platform Enforcement** - Strengthened iOS 26+ / macOS 26+ requirements
  - Added platform version enforcement documentation
  - Updated CLAUDE.md with strict version rules
  - Fixed platform support to macOS/iOS only (removed visionOS, tvOS, watchOS)

- **Code Quality** - Improved .swiftlint.yml maintainability with YAML anchors

---

## [1.3.0] - 2025-12-05

### Added

- **FixtureManager** - Thread-safe fixture access with caching
  - `FixtureManager.shared` singleton for centralized fixture management
  - Thread-safe access using locks with proper `defer` cleanup

### Changed

- **CI Workflow** - Updated for macOS 26 and improved reliability
  - Use correct iOS Simulator destination string
  - Run tests on both macOS and iOS platforms

### Fixed

- **Code Quality** - Improved code readability and test reliability

---

## [1.2.0] - 2025-11-26

### Added

- **Expanded Fixture API** - Improved fixture discovery implementation
  - Simplified `getFixture(filename:)` method
  - Better Xcode Cloud fixture discovery at test runtime

### Changed

- **Documentation** - Simplified to match current implementation

### Fixed

- **Xcode Cloud Support** - Improved CI detection for test runtime environments
  - Direct Xcode Cloud env var checks in `getFixturesDirectory`
  - Fixed `#filePath` to evaluate at call site for all public methods

---

## [1.1.0] - 2025-10-25

### Added

- **Fixture Discovery** - Multi-strategy fixture file discovery for Swift packages
  - CI_PRIMARY_REPOSITORY_PATH environment variable support (Xcode Cloud)
  - Bundle resource search for bundled Fixtures directories
  - File system traversal upward from #filePath

---

## [1.0.0] - 2025-11-01

### Added

- Initial release of SwiftFijos
- **Fijos.fixture()** - Discover test fixture files in Swift packages
- Cross-platform support for iOS 26+ and macOS 26+

---

## Version History

SwiftFijos provides test fixture file discovery for Swift packages and Xcode projects.
