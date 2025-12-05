# Trip Visualizer CLI Tool - Implementation Plan

A Swift command-line tool that fetches trip logs from Datadog by `tripID` and visualizes the route on Google Maps.

---

## User Requirements

- **Output format**: HTML file with Google Maps JavaScript API
- **Waypoint count**: 50+ waypoints per trip
- **Log structure**: Coordinates stored as JSON in log message field

---

## Communicating with Datadog (3 Approaches)

### 1. Direct REST API with URLSession (RECOMMENDED)

**How it works:**
- Use Swift's built-in `URLSession` to call Datadog's Log Search API
- Endpoint: `POST https://api.datadoghq.com/api/v2/logs/events/search`
- Query logs by custom attribute: `@tripID:your-trip-id`

**Authentication:**
- `DD-API-KEY` header: API key from Datadog account settings
- `DD-APPLICATION-KEY` header: Application key for authorization

**Pros:**
- Zero external dependencies (Foundation only)
- Full control over requests/responses
- Modern async/await support
- Minimal binary size

**Cons:**
- Manual JSON serialization
- Manual pagination handling
- Must implement retry logic

---

### 2. Wrapper Around System curl

**How it works:**
- Execute system `curl` commands from Swift using `Process`
- Pipe output back and parse JSON responses

**Pros:**
- Leverages battle-tested curl
- No Swift HTTP code needed

**Cons:**
- Security concerns with string escaping
- System dependency (curl must exist)
- Harder to parse responses
- Poor error handling
- Not portable

---

### 3. Official SDK (NOT VIABLE)

**Why not:**
- Datadog does NOT provide an official Swift API client for log querying
- `dd-sdk-ios` is for sending logs from iOS apps, not querying logs
- Official clients exist only for: Go, Python, Ruby, Java, JavaScript, Rust

---

## Communicating with Google Maps (3 Approaches)

### 1. Google Maps URLs (SIMPLEST)

**How it works:**
- Construct a URL: `https://www.google.com/maps/dir/?api=1&origin=START&destination=END&waypoints=WP1|WP2|WP3`
- Open in browser via `open` command on macOS

**Authentication:** None required

**Pros:**
- Zero dependencies or API setup
- No API key required
- Free (no billing)
- Interactive (user can pan/zoom)

**Cons:**
- Max 9 waypoints (desktop), 3 (mobile)
- URL length limit: 2,048 characters
- Requires browser

---

### 2. Google Maps Static API

**How it works:**
- HTTP GET to `https://maps.googleapis.com/maps/api/staticmap`
- Parameters: size, markers, path, key
- Returns PNG/JPEG image

**Authentication:**
- API key from Google Cloud Console
- Enable "Maps Static API"

**Pros:**
- Simple HTTP request
- Generates image file (can save/embed)
- Works in headless environments
- Good for reports/logs

**Cons:**
- Max 640x640 resolution
- URL length limit: 16,384 characters
- Requires API key + billing

---

### 3. Google Maps JavaScript API (RECOMMENDED for 50+ waypoints)

**How it works:**
- Generate HTML file with embedded JavaScript
- Use `google.maps.Polyline` for route visualization
- Use `google.maps.Marker` for start/end points
- Open in browser

**Authentication:**
- API key from Google Cloud Console
- Enable "Maps JavaScript API"

**Pros:**
- Unlimited waypoints
- Fully interactive
- Rich customization

**Cons:**
- Requires browser
- More complex implementation
- Requires API key + billing

---

## Recommendation Summary

| Service | Recommended Approach | Dependencies |
|---------|---------------------|--------------|
| **Datadog** | REST API with URLSession | Foundation only |
| **Google Maps** | JavaScript API (HTML file) | API key |

This combination achieves the goal of minimal third-party libraries while supporting 50+ waypoints with full interactivity.

---

## Implementation Plan

### Project Structure

```
TripVisualizer/
├── Package.swift
├── Sources/
│   └── TripVisualizer/
│       ├── main.swift              # Entry point, argument parsing
│       ├── DatadogClient.swift     # Datadog API integration
│       ├── Models.swift            # Data models (LogEntry, Coordinate, Trip)
│       ├── LogParser.swift         # Parse coordinates from JSON in messages
│       └── MapGenerator.swift      # Generate HTML with Google Maps JS API
└── README.md
```

### Step 1: Create Swift Package

- Initialize with `swift package init --type executable`
- No external dependencies (Swift 5.5+ for async/await)

### Step 2: Implement Argument Parsing

```swift
// main.swift
@main
struct TripVisualizer {
    static func main() async throws {
        guard CommandLine.arguments.count >= 2 else {
            print("Usage: trip-visualizer <tripID> [--output <path>]")
            exit(1)
        }
        let tripID = CommandLine.arguments[1]
        // ...
    }
}
```

### Step 3: Implement Datadog Client

- Use `URLSession` with async/await
- Headers: `DD-API-KEY`, `DD-APPLICATION-KEY` (from environment variables)
- Query: `@tripID:<id>` with pagination support
- Parse JSON response into `LogEntry` models

### Step 4: Implement Log Parser

- Extract JSON from log message field
- Parse lat/lng coordinates from JSON structure
- Sort by timestamp to maintain route order
- Return array of `Coordinate(lat: Double, lng: Double, timestamp: Date)`

### Step 5: Implement Map Generator

- Generate self-contained HTML file
- Include Google Maps JavaScript API via `<script>` tag
- Create `google.maps.Polyline` for the route
- Add `google.maps.Marker` for start/end points
- Auto-fit bounds to show entire route

### Step 6: Output

- Write HTML file to specified path (default: `trip_<id>.html`)
- Print path to console
- Optionally open in browser via `open` command

---

## Environment Variables Required

```bash
export DD_API_KEY="your-datadog-api-key"
export DD_APP_KEY="your-datadog-application-key"
export GOOGLE_MAPS_API_KEY="your-google-maps-api-key"
```

---

## Example Usage

```bash
# Basic usage
./trip-visualizer abc123

# Custom output path
./trip-visualizer abc123 --output ~/Desktop/my-trip.html

# Open in browser after generation
./trip-visualizer abc123 --open
```
