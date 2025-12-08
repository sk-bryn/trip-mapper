# Trip Visualizer

A Swift command-line tool for visualizing delivery trip routes from DataDog logs onto Google Maps.

## Overview

Trip Visualizer fetches trip route data from DataDog logs and generates map visualizations using Google Maps APIs. It supports multiple output formats and flexible configuration options.

## Requirements

- Swift 5.5 or later
- macOS 12+ or Linux with Swift 5.5+
- DataDog API credentials
- Google Maps API key

## Installation

### Building from Source

```bash
git clone <repository-url>
cd TripVisualizer
swift build -c release
```

The executable will be at `.build/release/tripvisualizer`.

### Running Tests

```bash
swift test
```

## Configuration

### Environment Variables (Required)

Set these environment variables before running:

```bash
export DD_API_KEY="your-datadog-api-key"
export DD_APP_KEY="your-datadog-app-key"
export GOOGLE_MAPS_API_KEY="your-google-maps-api-key"
```

### Configuration File (Optional)

Configuration is loaded from the following locations (in priority order):

1. Path specified via `--config` flag
2. `./config.json` (current directory)
3. `~/.tripvisualizer/config.json` (home directory)
4. Built-in defaults

Example configuration file:

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

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `outputDirectory` | String | `"output"` | Directory for generated files |
| `outputFormats` | Array | `["image", "html"]` | Output formats to generate |
| `datadogRegion` | String | `"us1"` | DataDog API region (us1, us3, us5, eu, ap1) |
| `datadogEnv` | String | `"prod"` | DataDog environment filter |
| `datadogService` | String | `"delivery-driver-service"` | DataDog service filter |
| `mapWidth` | Int | `800` | Static map width in pixels |
| `mapHeight` | Int | `600` | Static map height in pixels |
| `routeColor` | String | `"0000FF"` | Route polyline color (hex) |
| `routeWeight` | Int | `4` | Route polyline weight in pixels |
| `logLevel` | String | `"info"` | Log level (debug, info, warning, error) |
| `retryAttempts` | Int | `3` | Network retry count |
| `timeoutSeconds` | Int | `30` | Network timeout in seconds |

## Usage

### Basic Usage

```bash
tripvisualizer <trip-uuid>
```

### Examples

```bash
# Generate default outputs (image + HTML)
tripvisualizer 123e4567-e89b-12d3-a456-426614174000

# Generate specific formats
tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -f html -f image

# Generate all formats
tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -f all

# Custom output directory
tripvisualizer 123e4567-e89b-12d3-a456-426614174000 --output ./maps

# Use custom config with verbose logging
tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -c myconfig.json -v

# Quiet mode for scripting
tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -f all -q
```

### Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--format <format>` | `-f` | Output format (image, html, url, all). Can be repeated. |
| `--output <dir>` | `-o` | Output directory for generated files |
| `--config <path>` | `-c` | Path to JSON configuration file |
| `--verbose` | `-v` | Enable debug output |
| `--quiet` | `-q` | Suppress all output except errors |
| `--help` | `-h` | Show help information |
| `--version` | | Show version |

### Output Formats

| Format | Description |
|--------|-------------|
| `image` | Static PNG map image via Google Maps Static API |
| `html` | Interactive HTML map with pan/zoom controls |
| `url` | Print Google Maps URLs to stdout (no file created) |
| `all` | Generate all formats |

## Output Structure

Generated files are organized by trip ID:

```
output/
  <trip-uuid>/
    <trip-uuid>.html    # Interactive map
    <trip-uuid>.png     # Static map image
```

## Logging

Logs are written to both stderr and a trip-specific log file:

```
logs/<trip-uuid>-<timestamp>.log
```

Log levels:
- `debug` - Detailed diagnostic information
- `info` - General operational information
- `warning` - Potential issues that don't prevent operation
- `error` - Errors that prevent successful completion

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Environment error (missing API keys) |
| 2 | Network error (API failures, timeouts) |
| 3 | Data error (invalid trip ID, no route data) |
| 4 | Output error (cannot write files) |

## Architecture

```
TripVisualizer/
  Sources/TripVisualizer/
    Commands/                # CLI command definitions
    Models/                  # Data models (Trip, Waypoint, Configuration)
    Services/                # Business logic (DataDogClient, MapGenerator, etc.)
    Utilities/               # Helpers (Logger, ProgressIndicator, etc.)
    TripVisualizerCLI.swift  # Entry point (@main)
  Tests/TripVisualizerTests/
    Models/                  # Model tests
    Services/                # Service tests
    Integration/             # End-to-end tests
```

### Key Components

- **TripVisualizerService**: Main orchestrator that coordinates the pipeline
- **DataDogClient**: Fetches logs from DataDog API
- **LogParser**: Extracts waypoints from log data
- **MapGenerator**: Creates map visualizations
- **ConfigurationLoader**: Handles configuration discovery and loading
- **Logger**: Centralized logging with file output
- **ProgressIndicator**: CLI progress feedback

## Development

### Prerequisites

- Xcode 13+ (macOS) or Swift 5.5+ toolchain (Linux)
- DataDog account with API access
- Google Cloud account with Maps API enabled

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release
```

### Testing

```bash
# Run all tests
swift test

# Run specific test
swift test --filter ConfigurationTests
```

## License

[Add license information here]
