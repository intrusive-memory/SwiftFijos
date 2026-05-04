# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For detailed project documentation, architecture, and development guidelines, see **[AGENTS.md](AGENTS.md)**.

## Quick Reference

**Project**: SwiftFijos - Test fixture file discovery for Swift packages and Xcode projects

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Fixture discovery via CI env vars, bundle search, and file system traversal
- Thread-safe fixture access with `FixtureManager` actor
- URL caching and preloading for performance
- Security-scoped resource support (macOS)
- Access statistics for debugging parallel test execution

**Important Notes**:
- ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- Use `FixtureManager` for parallel test execution to prevent race conditions
- Fixtures directory must be added to "Copy Bundle Resources" for bundled tests
- See [AGENTS.md](AGENTS.md) for complete API reference, usage patterns, and thread safety details
