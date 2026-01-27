# Changelog

All notable changes to SwiftFijos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Changed

- **CI/CD Updates** - Disabled iOS tests
  - Only macOS unit tests run on PRs
  - Branch protection updated to match

- **Platform Enforcement** - Strengthened iOS 26+ / macOS 26+ requirements
  - Added platform version enforcement documentation
  - Updated CLAUDE.md with strict version rules
  - Cleaned up platform enforcement docs

- **Code Quality** - Improved .swiftlint.yml maintainability with YAML anchors

---

## [1.2.0] - 2026-01-15

### Added

- **Project Icon** - Added icon.jpg and SwiftFijos.png

### Changed

- **Platform Support** - Fixed to macOS/iOS only (removed visionOS, tvOS, watchOS)
- **CI Workflow** - Added concurrency controls, fixed iOS Simulator destination string

---

## [1.1.0] - 2025-12-01

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
