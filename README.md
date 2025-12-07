# Trip Visualizer

A Swift command line tool that visualizes delivery trip routes by fetching log data from DataDog and generating Google Maps visualizations.

## Features

- Fetch trip route data from DataDog logs
- Generate interactive HTML maps with route polylines
- Generate static PNG map images
- Display delivery markers for each order stop
- Support for multiple output formats (HTML, PNG, URLs)
- Configurable via command line options or config file
- Automatic retry with exponential backoff for network failures
- Progress indicators for long-running operations
- Graceful degradation when optional outputs fail

## Prerequisites

- macOS 10.15+ or Linux
- Swift 5.5+
- DataDog API credentials (API Key and Application Key)
- Google Maps API Key (with Static Maps API enabled)

## Installation

### Build from Source

```bash
# Clone the repository
git clone <repository-url>
cd trip-mapper

# Create .env file with your API keys
cp .env.example .env
# Edit .env with your actual API keys

# Build the tool
./build.sh
```

## Configuration

### Environment Variables

Create a `.env` file in the project root with the following variables:

```
DD_API_KEY=your_datadog_api_key
DD_APP_KEY=your_datadog_application_key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### Config File (Optional)

Create `~/.tripvisualizer/config.json` or `./config.json`:

```json
{
  "outputDirectory": "output",
  "outputFormats": ["image", "html"],
  "datadogRegion": "us1",
  "datadogEnv": "prod",
  "datadogService": "delivery-driver-service",
  "mapWidth": 800,
  "mapHeight": 600,
  "routeColor": "0000FF",
  "routeWeight": 4,
  "logLevel": "info",
  "retryAttempts": 3,
  "timeoutSeconds": 30
}
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `outputDirectory` | `output` | Directory for generated files |
| `outputFormats` | `["image", "html"]` | Output formats to generate |
| `datadogRegion` | `us1` | DataDog API region |
| `datadogEnv` | `prod` | DataDog environment filter |
| `datadogService` | `delivery-driver-service` | DataDog service filter |
| `mapWidth` | `800` | Static map width in pixels |
| `mapHeight` | `600` | Static map height in pixels |
| `routeColor` | `0000FF` | Route polyline color (hex) |
| `routeWeight` | `4` | Route polyline weight in pixels |
| `logLevel` | `info` | Logging verbosity (debug, info, warning, error) |
| `retryAttempts` | `3` | Network retry count |
| `timeoutSeconds` | `30` | Network timeout |

## Usage

### Basic Usage

```bash
# Using the run script (recommended)
./run.sh <trip-uuid>

# Example
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a
```

### Command Line Options

```bash
tripvisualizer [OPTIONS] <trip-id>

Arguments:
  <trip-id>              The UUID of the trip to visualize

Options:
  -o, --output <dir>     Output directory (default: output)
  -f, --format <format>  Output format: image, html, url, all (can be repeated)
  -c, --config <path>    Path to configuration file
  -v, --verbose          Enable verbose (debug) logging
  -q, --quiet            Suppress all output except errors
  -h, --help             Show help information
  --version              Show version information
```

### Examples

```bash
# Generate default outputs (PNG + HTML)
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a

# Generate only HTML
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a -f html

# Generate all formats
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a -f all

# Custom output directory
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a -o ./maps

# Use custom config file
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a -c ./my-config.json

# Verbose output for debugging
./run.sh 13a40f55-d849-45f1-a8e5-fa443acedb4a -v
```

### Output

The tool generates outputs in `output/<trip-id>/`:

```
output/
  13A40F55-D849-45F1-A8E5-FA443ACEDB4A/
    13A40F55-D849-45F1-A8E5-FA443ACEDB4A.html   # Interactive map
    13A40F55-D849-45F1-A8E5-FA443ACEDB4A.png    # Static map image
```

## Development

### Project Structure

```
trip-mapper/
├── TripVisualizer/
│   ├── Package.swift
│   └── Sources/
│       └── TripVisualizer/
│           ├── main.swift              # CLI entry point
│           ├── Models/                 # Data models
│           │   ├── Configuration.swift
│           │   ├── Trip.swift
│           │   ├── Waypoint.swift
│           │   └── Errors.swift
│           ├── Services/               # Business logic
│           │   ├── TripVisualizer.swift
│           │   ├── DataDogClient.swift
│           │   ├── LogParser.swift
│           │   └── MapGenerator.swift
│           └── Utilities/              # Helpers
│               ├── Environment.swift
│               └── Logger.swift
├── build.sh                            # Build script
├── run.sh                              # Run script
├── .env                                # API keys (not committed)
└── output/                             # Generated visualizations
```

### Running Tests

```bash
cd TripVisualizer
swift test
```

### Building

```bash
# Debug build
./build.sh

# Release build
cd TripVisualizer
swift build -c release
```

## Supported DataDog Regions

- `us1` (default) - US East
- `us3` - US West
- `us5` - US Central
- `eu` - Europe
- `ap1` - Asia Pacific

## License

Private - Internal Use Only
