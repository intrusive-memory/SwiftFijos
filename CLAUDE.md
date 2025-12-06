# SwiftFijos

Test fixture file discovery for Swift packages and Xcode projects.

**Platforms**: macOS 26.0+ / iOS 26.0+

## ⚠️ CRITICAL: Platform Version Enforcement

**This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.**

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

**DO NOT lower the platform requirements to support older iOS/macOS versions.**

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
