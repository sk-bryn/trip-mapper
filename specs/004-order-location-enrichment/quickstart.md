# Quickstart: Order & Location Enrichment

**Feature**: 004-order-location-enrichment
**Date**: 2025-12-08

## Overview

This guide provides step-by-step instructions for implementing the Order & Location Enrichment feature.

---

## Prerequisites

- Existing TripVisualizer codebase with features 001-003 implemented
- DataDog API credentials (DD_API_KEY, DD_APP_KEY)
- Google Maps API key (GOOGLE_MAPS_API_KEY)
- Swift 5.5+ toolchain

---

## Implementation Steps

### Step 1: Create New Model Files

Create the following new Swift files in `TripVisualizer/Sources/TripVisualizer/Models/`:

1. **DeliveryDestination.swift** - Order delivery address entity
2. **RestaurantLocation.swift** - Restaurant location entity
3. **EnrichmentStatus.swift** - Status flags
4. **EnrichmentResult.swift** - Combined enrichment data
5. **MarkerStyle.swift** - Marker configuration

Reference: [data-model.md](./data-model.md)

### Step 2: Add Configuration Fields

Modify `Configuration.swift` to add marker style configuration:

```swift
public var deliveryDestinationMarkerStyle: MarkerStyle
public var restaurantOriginMarkerStyle: MarkerStyle
```

Add defaults and Codable support as documented in data-model.md.

### Step 3: Create EnrichmentService

Create `TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift`:

```swift
public final class EnrichmentService {
    private let dataDogClient: DataDogClient
    private let configuration: Configuration

    public init(dataDogClient: DataDogClient, configuration: Configuration) {
        self.dataDogClient = dataDogClient
        self.configuration = configuration
    }

    public func fetchEnrichmentData(
        tripId: UUID,
        orderIds: [UUID],
        locationNumber: String?
    ) async -> EnrichmentResult {
        // Implementation per research.md decisions
    }
}
```

Reference: [contracts/datadog-enrichment-queries.md](./contracts/datadog-enrichment-queries.md)

### Step 4: Extend DataDogClient

Add methods to `DataDogClient.swift` for enrichment queries:

```swift
public func fetchDeliveryOrderLogs(
    tripId: UUID,
    limit: Int = 50
) async throws -> [DataDogLogEntry]

public func fetchLocationDetailsLogs(
    limit: Int = 10
) async throws -> [DataDogLogEntry]
```

### Step 5: Modify MapGenerator

Update `MapGenerator.swift` to render enrichment markers:

1. Add `generateEnrichmentMarkersJS()` method
2. Modify `generateHTML()` to include enrichment markers
3. Modify `generateStaticMapsURL()` to include enrichment markers
4. Update legend to show new marker types

Reference: [contracts/map-enrichment-markers.md](./contracts/map-enrichment-markers.md)

### Step 6: Modify TripDataExport

Update `TripDataExport.swift` to include enrichment data:

1. Add `restaurantLocation`, `deliveryDestinations`, `enrichmentStatus`, `enrichmentWarnings` fields
2. Update `from()` factory method to accept EnrichmentResult
3. Update JSON encoding

### Step 7: Modify DataExportGenerator

Update `DataExportGenerator.swift` to include enrichment in export:

```swift
public func generateExport(
    tripId: UUID,
    logs: [LogFragment],
    route: UnifiedRoute,
    metadata: TripMetadata,
    enrichment: EnrichmentResult
) -> TripDataExport
```

### Step 8: Integrate into TripVisualizer Service

Update the main `TripVisualizer.swift` service to:

1. Extract orderIds from route waypoints
2. Extract locationNumber from trip metadata or logs
3. Call EnrichmentService.fetchEnrichmentData()
4. Pass enrichment to MapGenerator and DataExportGenerator

---

## Testing Checklist

### Unit Tests Required

- [ ] `DeliveryDestinationTests.swift` - Entity creation and validation
- [ ] `RestaurantLocationTests.swift` - Entity creation and validation
- [ ] `EnrichmentResultTests.swift` - Factory methods and status computation
- [ ] `EnrichmentServiceTests.swift` - DataDog query parsing
- [ ] `MapGeneratorEnrichmentTests.swift` - Marker generation
- [ ] `TripDataExportEnrichmentTests.swift` - Export includes enrichment

### Integration Tests

- [ ] Full visualization with enrichment data available
- [ ] Full visualization with partial enrichment (orders only)
- [ ] Full visualization with partial enrichment (location only)
- [ ] Full visualization with no enrichment data (graceful degradation)

---

## Configuration Example

Add to `config.json`:

```json
{
  "deliveryDestinationMarkerStyle": {
    "icon": "home",
    "color": "9900FF"
  },
  "restaurantOriginMarkerStyle": {
    "icon": "restaurant",
    "color": "0066FF"
  }
}
```

---

## Verification Commands

After implementation, verify with:

```bash
# Build
swift build

# Run tests
swift test

# Test with real trip
./.build/debug/tripvisualizer visualize --trip-id <test-trip-uuid>

# Check output
cat output/<trip-id>-data.json | jq '.enrichmentStatus'
```

---

## Expected Output

### map-data.json with enrichment
```json
{
  "tripId": "...",
  "enrichmentStatus": {
    "orderDataFound": true,
    "locationDataFound": true
  },
  "restaurantLocation": {
    "name": "West Columbia",
    "address1": "2299 Augusta Rd",
    "city": "West Columbia",
    "state": "SC",
    "zip": "29169",
    "latitude": 33.98325,
    "longitude": -81.096
  },
  "deliveryDestinations": [
    {
      "orderId": "...",
      "address": "123 Main St, Atlanta, GA, 30301",
      "latitude": 33.7490,
      "longitude": -84.3880
    }
  ]
}
```

### HTML map
- Purple "home" markers for delivery destinations
- Blue "restaurant" marker for restaurant origin
- Updated legend showing all marker types

---

## Troubleshooting

### No enrichment data found
1. Check DataDog query in logs
2. Verify tripId exists in logs with GetDeliveryOrder messages
3. Verify location_number exists in GetLocationsDetails logs

### Markers not showing
1. Check enrichmentStatus in map-data.json
2. Verify coordinates are valid
3. Check marker style configuration

### Parsing errors
1. Check log output for parsing warnings
2. Verify DataDog response structure matches contracts
3. Review field mappings in EnrichmentService

