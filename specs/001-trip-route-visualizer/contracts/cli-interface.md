# CLI Interface Contract

**Date**: 2025-12-04
**Feature**: 001-trip-route-visualizer

## Command: tripvisualizer

### Synopsis

```
tripvisualizer <trip-id> [options]
tripvisualizer --help
tripvisualizer --version
```

### Arguments

| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `<trip-id>` | UUID | Yes | The trip identifier to visualize |

### Options

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--output` | `-o` | Path | `.` | Output directory for generated files |
| `--format` | `-f` | String | `all` | Output format: `image`, `html`, `url`, or `all` |
| `--config` | `-c` | Path | - | Path to configuration file |
| `--verbose` | `-v` | Flag | false | Enable verbose output |
| `--quiet` | `-q` | Flag | false | Suppress progress output |
| `--help` | `-h` | Flag | - | Show help message |
| `--version` | - | Flag | - | Show version information |

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DD_API_KEY` | Yes | DataDog API key |
| `DD_APP_KEY` | Yes | DataDog Application key |
| `GOOGLE_MAPS_API_KEY` | Yes | Google Maps API key |

### Output

#### Success (Exit Code 0)

**stdout**:
```
Generated: /path/to/output/<trip-id>.png
Generated: /path/to/output/<trip-id>.html
URL: https://www.google.com/maps/...
```

**stderr** (with `--verbose`):
```
[INFO] Validating trip ID...
[INFO] Fetching logs from DataDog...
[INFO] Found 15 log entries
[INFO] Extracted 127 waypoints
[INFO] Generating visualization...
[INFO] Complete
```

#### Error (Exit Code > 0)

**stderr**:
```
Error: <user-friendly message>
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid input (bad UUID, missing args) |
| 2 | Network error (API unreachable, timeout) |
| 3 | Data error (trip not found, no route data, < 2 waypoints) |
| 4 | Output error (cannot write files) |
| 5 | Configuration error (missing env vars, bad config file) |

### Examples

```bash
# Basic usage
tripvisualizer 550e8400-e29b-41d4-a716-446655440000

# Specify output directory
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -o ./maps

# Generate only HTML
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -f html

# Verbose output
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -v

# Use custom config
tripvisualizer 550e8400-e29b-41d4-a716-446655440000 -c ./myconfig.json
```

### Log File

All operations are logged to: `logs/<trip-id>-<timestamp>.log`

Log format:
```
[2025-12-04T10:30:00Z] [INFO] Starting visualization for trip 550e8400-...
[2025-12-04T10:30:01Z] [DEBUG] DataDog query: @tripID:550e8400-...
[2025-12-04T10:30:02Z] [INFO] Retrieved 15 log entries
...
```
