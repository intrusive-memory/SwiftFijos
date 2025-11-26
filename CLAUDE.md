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

1. **Xcode Cloud**: Uses `CI_PRIMARY_REPOSITORY_PATH`, then `CI_WORKSPACE`
2. **Local Xcode Projects**: Searches for `.xcodeproj` or `.xcworkspace`
3. **Swift Packages**: Searches for `Package.swift`
4. **Fallback**: Recursive directory search
