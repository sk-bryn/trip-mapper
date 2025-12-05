# Research: Trip Route Visualizer CLI

**Date**: 2025-12-04
**Feature**: 001-trip-route-visualizer

## Research Topics

### 1. DataDog REST API v2 - Log Search

**Decision**: Use DataDog Logs Search API v2 with POST requests

**Rationale**:
- Official REST API with stable v2 endpoints
- Supports complex queries including custom attributes like `@tripID`
- Returns paginated JSON results with full log content
- Authentication via `DD-API-KEY` and `DD-APPLICATION-KEY` headers

**Endpoint**: `POST https://api.datadoghq.com/api/v2/logs/events/search`

**Query Structure**:
```json
{
  "filter": {
    "query": "@tripID:<uuid>",
    "from": "now-30d",
    "to": "now"
  },
  "sort": "timestamp",
  "page": {
    "limit": 1000
  }
}
```

**Alternatives Considered**:
- DataDog Python/Go SDKs: Rejected due to Swift requirement and no external dependencies constraint
- Log archives: Rejected due to complexity and latency

---

### 2. Google Maps Visualization - Static Image Generation

**Decision**: Use Google Maps Static API for PNG output + generate HTML with JavaScript API for interactive view

**Rationale**:
- Static Maps API generates PNG images directly via URL
- URL-based approach works in headless CLI environment
- JavaScript API in HTML provides interactive fallback with no waypoint limits
- Encoded polyline format supports efficient URL encoding of route paths

**Static Maps API URL Pattern**:
```
https://maps.googleapis.com/maps/api/staticmap
  ?size=800x600
  &path=enc:<encoded_polyline>
  &key=<API_KEY>
```

**Limitations**:
- Static Maps API: Max 8192 characters in URL (approximately 200-400 waypoints with encoding)
- For larger routes: Use path simplification (Douglas-Peucker algorithm) or generate HTML only

**Alternatives Considered**:
- Mapbox Static API: Similar functionality, but Google Maps specified in requirements
- Server-side rendering with headless browser: Rejected due to complexity and external dependencies

---

### 3. Polyline Encoding Algorithm

**Decision**: Implement Google's Polyline Encoding Algorithm in Swift

**Rationale**:
- Required for efficient Static Maps API URLs
- Well-documented algorithm with clear specification
- Compresses coordinate data significantly (5-10x reduction)
- Standard implementation across Google Maps ecosystem

**Algorithm Overview**:
1. Take difference from previous point
2. Multiply by 1e5 and round
3. Left-shift and invert if negative
4. Break into 5-bit chunks
5. Add 63 to each chunk and convert to ASCII

**Alternatives Considered**:
- Unencoded coordinate lists: Rejected due to URL length limits
- Third-party encoding libraries: Rejected due to no external dependencies constraint

---

### 4. Swift CLI Argument Parsing

**Decision**: Use Swift ArgumentParser package (exception to no-dependencies rule)

**Rationale**:
- Official Apple package for CLI applications
- Provides declarative argument parsing with automatic help generation
- Type-safe and integrates with Swift's error handling
- Widely adopted standard for Swift CLI tools
- Minimal, focused dependency with no transitive dependencies

**Alternative Decision**: If strict no-dependencies required, implement manual argument parsing using `CommandLine.arguments`

**Alternatives Considered**:
- Manual `CommandLine.arguments` parsing: Viable but verbose, no automatic help
- getopt-style parsing: Non-idiomatic for Swift

---

### 5. Configuration File Format

**Decision**: Use JSON configuration files

**Rationale**:
- Native Swift `Codable` support via `JSONDecoder`
- No external dependencies required
- Human-readable and easy to edit
- Standard format familiar to developers

**Config File Location**: `~/.tripvisualizer/config.json` or `./config.json` (local override)

**Alternatives Considered**:
- YAML: Requires external parser
- Property lists (plist): macOS-specific, less portable
- TOML: Requires external parser

---

### 6. Cross-Platform Considerations

**Decision**: Conditional compilation for platform-specific code

**Rationale**:
- URLSession available on both macOS and Linux (via swift-corelibs-foundation)
- File system operations via FileManager work cross-platform
- Use `#if os(macOS)` / `#if os(Linux)` for any platform differences

**Key Differences**:
- Opening browser: `NSWorkspace.shared.open()` on macOS, `xdg-open` on Linux
- Home directory: `FileManager.default.homeDirectoryForCurrentUser` works on both

**Alternatives Considered**:
- Platform-specific builds: Rejected due to maintenance overhead

---

### 7. Progress Reporting

**Decision**: Use stderr for progress output with ANSI escape codes

**Rationale**:
- Keeps stdout clean for machine-readable output
- ANSI codes provide visual feedback (spinner, percentage)
- Graceful fallback for non-TTY environments

**Implementation Pattern**:
```swift
// Check if stderr is a TTY
let isTTY = isatty(FileHandle.standardError.fileDescriptor) != 0
// Use \r to overwrite line for progress updates
```

**Alternatives Considered**:
- Separate progress file: Overly complex
- No progress: Poor UX for long operations

---

### 8. Error Handling Strategy

**Decision**: Use typed Swift errors with user-friendly messages

**Rationale**:
- Swift's `Error` protocol enables typed error handling
- Separate internal errors (logged) from user-facing messages (stderr)
- Exit codes follow Unix conventions

**Error Categories**:
| Exit Code | Category | Example |
|-----------|----------|---------|
| 0 | Success | - |
| 1 | Input validation error | Invalid UUID format |
| 2 | Network error | DataDog API unreachable |
| 3 | Data error | No route data found |
| 4 | Output error | Cannot write to output directory |

**Alternatives Considered**:
- Single generic error type: Less informative for users

---

## Summary

All technical decisions align with the constitution:
- No external dependencies except potentially ArgumentParser (justified)
- Cross-platform using Foundation only
- Security via environment variables
- CLI-first with proper I/O protocols
