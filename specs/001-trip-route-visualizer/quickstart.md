# Quickstart: Trip Route Visualizer CLI

**Date**: 2025-12-04
**Feature**: 001-trip-route-visualizer

## Prerequisites

### System Requirements

- **Swift**: 5.5 or later
- **Operating System**: macOS 12+ or Linux (Ubuntu 20.04+)
- **Network**: Access to DataDog and Google Maps APIs

### API Keys

You'll need the following API credentials:

1. **DataDog API Key** - From DataDog Organization Settings > API Keys
2. **DataDog Application Key** - From DataDog Organization Settings > Application Keys
3. **Google Maps API Key** - From Google Cloud Console with Static Maps API and Maps JavaScript API enabled

## Installation

### Build from Source

```bash
# Clone the repository
git clone <repository-url>
cd trip-mapper/TripVisualizer

# Build the project
swift build -c release

# The binary is located at:
# .build/release/tripvisualizer
```

### Install to PATH (Optional)

```bash
# Copy to local bin
cp .build/release/tripvisualizer /usr/local/bin/

# Or create symbolic link
ln -s $(pwd)/.build/release/tripvisualizer /usr/local/bin/tripvisualizer
```

## Configuration

### Environment Variables (Required)

Set the following environment variables before running:

```bash
export DD_API_KEY="your-datadog-api-key"
export DD_APP_KEY="your-datadog-application-key"
export GOOGLE_MAPS_API_KEY="your-google-maps-api-key"
```

**Tip**: Add these to your `~/.bashrc` or `~/.zshrc` for persistence.

### Configuration File (Optional)

Create `~/.tripvisualizer/config.json` for custom defaults:

```json
{
  "outputDirectory": "~/trip-maps",
  "outputFormats": ["image", "html"],
  "datadog": {
    "region": "us1",
    "env": "prod",
    "service": "delivery-driver-service",
    "queryTimeRange": "now-30d"
  },
  "googleMaps": {
    "imageWidth": 640,
    "imageHeight": 480,
    "mapType": "roadmap",
    "pathColor": "0000FF"
  },
  "logging": {
    "level": "info"
  }
}
```

**Note**: The `datadog.env` and `datadog.service` fields are used to construct the log query filter. Change `env` to `"test"` when querying test environment logs.

## Basic Usage

### Visualize a Trip

```bash
tripvisualizer 550e8400-e29b-41d4-a716-446655440000
```

This generates:
- `550e8400-e29b-41d4-a716-446655440000.png` - Static map image
- `550e8400-e29b-41d4-a716-446655440000.html` - Interactive map

### Specify Output Directory

```bash
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -o ./maps
```

### Generate Specific Format

```bash
# Only PNG image
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -f image

# Only HTML
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -f html

# Only URL (prints to stdout)
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -f url
```

### Verbose Output

```bash
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -v
```

## Example Workflow

```bash
# 1. Set up environment (one time)
export DD_API_KEY="abc123..."
export DD_APP_KEY="def456..."
export GOOGLE_MAPS_API_KEY="ghi789..."

# 2. Create output directory
mkdir -p ~/trip-investigations

# 3. Visualize a trip
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -o ~/trip-investigations -v

# 4. View the results
open ~/trip-investigations/550e8400-e29b-41d4-a716-446655440000.html  # macOS
# or
xdg-open ~/trip-investigations/550e8400-e29b-41d4-a716-446655440000.html  # Linux
```

## Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Missing DD_API_KEY` | Environment variable not set | Set `DD_API_KEY` |
| `Invalid UUID format` | Trip ID is not a valid UUID | Check the trip ID format |
| `Trip not found` | No logs exist for this trip | Verify trip ID, check time range |
| `No route data` | Logs exist but no coordinates | Check log format has `segment_coords` |
| `Insufficient waypoints` | Less than 2 waypoints found | Route cannot be visualized |

### Logs

Check the log file for detailed debugging:

```bash
cat logs/<trip-id>-<timestamp>.log
```

### Verify API Access

```bash
# Test DataDog connection
curl -X GET "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APP_KEY"

# Should return: {"valid": true}
```

## Help

```bash
tripvisualizer --help
```

## Next Steps

- Review [CLI Interface Contract](./contracts/cli-interface.md) for full command reference
- See [Data Model](./data-model.md) for entity details
- Check [DataDog API Contract](./contracts/datadog-api.md) for query customization
