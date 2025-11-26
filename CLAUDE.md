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

1. **CI Systems**: Checks repository path env vars (GitHub Actions, GitLab CI, CircleCI, Jenkins, Buildkite, Travis CI)
2. **`#filePath` Discovery**: Searches upward from test file to find project root
3. **Project Root Detection**: Looks for `.xcodeproj`, `.xcworkspace`, or `Package.swift`
4. **Fallback**: Recursive directory search

## Note on Xcode Cloud

Xcode Cloud environment variables (`CI`, `CI_PRIMARY_REPOSITORY_PATH`, `CI_WORKSPACE`) are only available during build scripts, NOT at test runtime. The library uses `#filePath` based discovery which works reliably in all environments.
