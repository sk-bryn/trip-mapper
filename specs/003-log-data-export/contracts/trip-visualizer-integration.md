# Contract: TripVisualizerService Integration

**Feature**: 003-log-data-export
**Date**: 2025-12-08

## Overview

Modifications to TripVisualizerService to integrate automatic data export generation.

## Modified Method

### visualize(tripId:)

**Current Behavior** (from 002-multi-log-trips):
1. Fetch logs from DataDog
2. Parse logs into LogFragments
3. Aggregate fragments into UnifiedRoute
4. Generate map outputs (HTML, PNG)
5. Return success with output paths

**New Behavior**:
1. Fetch logs from DataDog
2. Parse logs into LogFragments
3. Aggregate fragments into UnifiedRoute
4. Generate map outputs (HTML, PNG)
5. **NEW: Generate data export JSON**
6. Return success with output paths (including export path)

## Integration Point

```swift
// In TripVisualizerService.visualize(tripId:)

// After map generation completes successfully...

// Step N: Generate data export (always, per FR-001)
let exportGenerator = DataExportGenerator()
let exportPath = try exportGenerator.generateAndWrite(
    tripId: tripId,
    logs: logs,           // [LogFragment] from Step 2
    route: unifiedRoute,  // UnifiedRoute from Step 3
    metadata: metadata,   // TripMetadata from aggregation
    to: outputDirectory   // Same directory as map files
)

logInfo("Data export written to \(exportPath)")
```

## Error Handling

### Export Failure Strategy

Per spec edge case: "System reports error but still generates map outputs if possible"

Since export runs AFTER map generation:
- Map outputs are already written before export attempt
- Export failure should log warning, not throw error
- Visualization is considered successful even if export fails

```swift
do {
    let exportPath = try exportGenerator.generateAndWrite(...)
    logInfo("Data export written to \(exportPath)")
} catch {
    logWarning("Failed to generate data export: \(error.localizedDescription)")
    // Continue - map outputs already generated successfully
}
```

## Output File Location

**Directory**: Same as map outputs (`<outputDirectory>/<tripId>/`)

**Filename**: `<tripId>-data.json`

**Example**:
- Map: `output/13A40F55-D849-45F1-A8E5-FA443ACEDB4A/13A40F55-D849-45F1-A8E5-FA443ACEDB4A.html`
- Export: `output/13A40F55-D849-45F1-A8E5-FA443ACEDB4A/13A40F55-D849-45F1-A8E5-FA443ACEDB4A-data.json`

## Progress Indicator Updates

Add progress stage for export generation:

```swift
// In ProgressIndicator.Stage enum (if distinct stage needed)
case exporting = "Exporting data"

// Or use existing .generating stage with different message
progress.update("Writing data export...")
```

## Backward Compatibility

- No CLI interface changes
- No configuration changes
- Export is always generated (cannot be disabled)
- Existing output files unchanged in format/location
- Only addition is the new `-data.json` file

## Test Scenarios

1. **Normal flow**: Verify export file created alongside map files
2. **Export path**: Verify file at `<tripId>/<tripId>-data.json`
3. **Export content**: Verify JSON contains correct data from logs
4. **Export failure handling**: Verify warning logged but visualization succeeds
5. **Clean re-run**: Verify export file replaced on re-run (per existing cleanup logic)
