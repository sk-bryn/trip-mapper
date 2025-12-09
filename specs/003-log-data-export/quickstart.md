# Quickstart: Log Data Export

**Feature**: 003-log-data-export
**Date**: 2025-12-08

## Overview

This feature adds automatic JSON data export alongside trip visualizations. The export contains DataDog log metadata, route segment correlations, orderIds, and waypoint counts for independent verification of rendered maps.

## What's New

After this feature, every trip visualization will also produce a `map-data.json` file containing:

- Trip ID and generation timestamp
- Summary statistics (segment count, waypoint count, order count)
- Complete ordered sequence of orderIds
- Route segment details with:
  - Correlated DataDog log ID and URL
  - Timestamp
  - Waypoint count
  - Orders with their waypoint counts

## Usage

No changes to CLI usage. Export is automatic.

```bash
# Run visualizer as usual
./run.sh <tripId>

# Export file is created automatically
# Output: output/<tripId>/map-data.json
```

## Example Output Structure

```
output/13A40F55-D849-45F1-A8E5-FA443ACEDB4A/
├── 13A40F55-D849-45F1-A8E5-FA443ACEDB4A.html      # Interactive map
├── 13A40F55-D849-45F1-A8E5-FA443ACEDB4A.png       # Static map image
├── map-data.json                                  # NEW: Data export
└── route-segments/                                 # Per-segment outputs
```

## Verifying the Export

1. **Open the JSON file** in any text editor
2. **Check summary** matches map visualization (segment count, gap detection)
3. **Verify orderIds** sequence matches expected delivery order
4. **Click DataDog links** to view original log entries

## Sample Export Content

```json
{
  "tripId": "13A40F55-D849-45F1-A8E5-FA443ACEDB4A",
  "generatedAt": "2025-12-08T04:22:45Z",
  "summary": {
    "totalRouteSegments": 3,
    "totalWaypoints": 150,
    "totalOrders": 2,
    "hasGaps": true,
    "truncated": false,
    "incompleteData": false
  },
  "orderSequence": ["ORD-001", "ORD-002"],
  "routeSegments": [
    {
      "segmentIndex": 0,
      "datadogLogId": "abc123",
      "datadogUrl": "https://app.datadoghq.com/logs?query=@id:abc123",
      "timestamp": "2025-12-05T05:24:25Z",
      "waypointCount": 50,
      "orders": [
        { "orderId": "ORD-001", "waypointCount": 50 }
      ]
    }
  ]
}
```

## Testing Checklist

### Functional Tests

- [ ] Export file created for every visualization
- [ ] File named `map-data.json`
- [ ] File in same directory as map outputs
- [ ] JSON is pretty-printed (human-readable)
- [ ] JSON is valid (parseable by tools)

### Content Tests

- [ ] tripId matches visualization tripId
- [ ] generatedAt is current timestamp
- [ ] totalRouteSegments matches segment count on map
- [ ] totalWaypoints matches sum of segment waypoints
- [ ] totalOrders matches orderSequence length
- [ ] hasGaps matches gap segments on map
- [ ] orderSequence contains all unique orderIds in order
- [ ] Each segment has correct DataDog log correlation

### Link Tests

- [ ] datadogUrl opens correct log in DataDog console
- [ ] Each segment's log ID is traceable

### Edge Cases

- [ ] Single-segment trip (no gaps)
- [ ] Multi-segment trip with gaps
- [ ] Trip with no orderIds (empty orderSequence)
- [ ] Trip with truncated logs (truncated: true)
- [ ] Re-run replaces previous export file

## Troubleshooting

### Export file not created

- Check for errors in console output
- Verify output directory is writable
- Map outputs should still exist (export failure doesn't block maps)

### JSON parsing errors

- Open file in text editor to check for truncation
- Verify file has complete closing brackets

### Wrong orderIds

- OrderIds come from waypoint data in DataDog logs
- Check source logs have orderId field populated
- Empty orders array means no orderIds in that segment
