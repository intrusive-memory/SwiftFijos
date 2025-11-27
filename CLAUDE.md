# SwiftFijos

Test fixture file discovery for Swift packages and Xcode projects.

## Development

```bash
swift build
swift test
```

## Structure

- `Sources/SwiftFijos/Fijos.swift` - Main implementation
- `Tests/SwiftFijosTests/FijosTests.swift` - Test suite
- `Fixtures/` - Test fixture files

## Fixture Discovery Priority

1. `CI_PRIMARY_REPOSITORY_PATH` environment variable (Xcode Cloud)
2. Bundle resource search (for bundled Fixtures directories)
3. File system traversal upward from `#filePath`
