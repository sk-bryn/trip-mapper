# Research: Order & Location Enrichment

**Feature**: 004-order-location-enrichment
**Date**: 2025-12-08
**Status**: Complete

## Research Summary

This document captures technical decisions made during Phase 0 research for the Order & Location Enrichment feature.

---

## 1. DataDog Query Strategy for Enrichment Logs

### Decision
Use the same query filtering approach as existing route log queries, with function-specific message filters.

### Rationale
- Ensures data correlation by using identical env, service, and tripId filters
- Verified via `verify-grpc-logs.py` script that logs exist with expected data
- Query pattern `"handled request for <FunctionName>"` returns logs with response bodies

### Query Patterns

**Order Enrichment (GetDeliveryOrder)**:
```
env:<datadogEnv> @trip_id:<tripId> service:<datadogService> "handled request for GetDeliveryOrder"
```

**Restaurant Enrichment (GetLocationsDetails)**:
```
env:<datadogEnv> service:<datadogService> "handled request for GetLocationsDetails"
```
Note: Restaurant query may not include tripId since GetLocationsDetails uses location_number, not tripId.

### Alternatives Considered
1. **Use gRPC API directly**: Rejected because feature spec requires using DataDog logs as the data source for consistency with existing route visualization approach
2. **Separate time range for enrichment**: Rejected to maintain correlation with route data timestamps

---

## 2. Location Number Extraction

### Decision
Extract `location_number` from existing route log data or trip metadata.

### Rationale
- Route logs already contain trip metadata that may include location_number
- Avoids additional API calls
- Consistent with existing data flow

### Implementation Approach
1. First, check if location_number exists in trip route log attributes
2. If not found in route logs, search for GetLocationsDetails logs within the same time range
3. Log warning if location_number cannot be determined

### Alternatives Considered
1. **Require location_number as CLI input**: Rejected because it breaks the single-tripId input pattern
2. **Query GetTripDetails for location_number**: Rejected because spec requires DataDog logs as data source

---

## 3. Marker Visual Distinction

### Decision
Use both different icons AND different colors for each marker type, with styles configurable via existing configuration file.

### Rationale
- User clarified that both icons AND colors should differ
- Configuration allows team customization without code changes
- Follows existing pattern of config-driven styling (routeColor, routeWeight)

### Marker Types and Default Styles

| Marker Type | Default Icon | Default Color | Purpose |
|-------------|--------------|---------------|---------|
| Route Start | green-dot | Green | Trip start point |
| Route End | red-dot | Red | Trip end point |
| Route Waypoint | circle (existing) | Orange (#FF6600) | Existing delivery markers |
| Delivery Destination | home/house | Purple (#9900FF) | Intended delivery address |
| Restaurant Origin | restaurant/utensils | Blue (#0066FF) | Restaurant pickup location |

### Configuration Schema Addition
```json
{
  "markerStyles": {
    "deliveryDestination": {
      "icon": "home",
      "color": "9900FF"
    },
    "restaurantOrigin": {
      "icon": "restaurant",
      "color": "0066FF"
    }
  }
}
```

### Alternatives Considered
1. **Color only differentiation**: Rejected per user clarification requiring both icon AND color
2. **Hardcoded styles**: Rejected because constitution requires modular configuration

---

## 4. Graceful Degradation Strategy

### Decision
Continue generating all visualization artifacts even when enrichment data is unavailable, with status indicators in map-data.json.

### Rationale
- User explicitly clarified this behavior
- Matches FR-009, FR-017, FR-018, FR-019 in spec
- Visualization remains useful even without enrichment

### Implementation Approach
1. Attempt enrichment queries in parallel with route processing (where possible)
2. On failure, log warning and continue
3. Include `enrichmentStatus` section in map-data.json:
```json
{
  "enrichmentStatus": {
    "orderDataFound": true,
    "locationDataFound": false,
    "warnings": ["Restaurant location not found for location_number 00070"]
  }
}
```

### Alternatives Considered
1. **Fail visualization if enrichment fails**: Rejected because route visualization has value independent of enrichment
2. **Retry enrichment indefinitely**: Rejected because it would block visualization completion

---

## 5. Enrichment Data Structure

### Decision
Create dedicated Swift structs for enrichment entities following existing model patterns.

### Rationale
- Maintains strongly-typed Swift requirement from constitution
- Follows existing patterns (Waypoint, LogFragment, etc.)
- Enables proper JSON encoding/decoding

### Entity Mapping from DataDog Response

**DeliveryDestination** (from GetDeliveryOrder):
- `orderId: UUID`
- `address: String` (full concatenated address)
- `addressDisplayLine1: String`
- `addressDisplayLine2: String`
- `coordinates: Coordinates` (latitude, longitude)
- `dropoffInstructions: String?` (if available)

**RestaurantLocation** (from GetLocationsDetails):
- `locationNumber: String`
- `name: String`
- `address1: String`
- `address2: String?`
- `city: String`
- `state: String`
- `zip: String`
- `coordinates: Coordinates`
- `operatorName: String?`
- `timeZone: String?`

**EnrichmentResult**:
- `restaurantLocation: RestaurantLocation?`
- `deliveryDestinations: [DeliveryDestination]`
- `status: EnrichmentStatus`
- `warnings: [String]`

**EnrichmentStatus**:
- `orderDataFound: Bool`
- `locationDataFound: Bool`

---

## 6. Parallel Fetching Strategy

### Decision
Fetch enrichment data in parallel where data dependencies allow.

### Rationale
- Minimizes latency impact per spec assumptions
- OrderIds are known before enrichment starts (from route waypoints)
- Restaurant query is independent of order queries

### Implementation Approach
```swift
async let restaurantResult = fetchRestaurantLocation(locationNumber)
async let ordersResult = fetchDeliveryOrders(orderIds)

let (restaurant, orders) = await (try? restaurantResult, try? ordersResult)
```

### Alternatives Considered
1. **Sequential fetching**: Rejected because it unnecessarily increases latency
2. **Batch all orderIds in single query**: Not possible - GetDeliveryOrder takes single orderId

---

## 7. Existing Delivery Markers vs New Intended Destination Markers

### Decision
Keep existing delivery markers (showing where driver actually went) and add new intended destination markers (showing where orders should be delivered).

### Rationale
- User story explicitly states: "enabling comparison between where the driver was supposed to go versus where they actually drove"
- FR-014 requires distinct markers for intended vs actual
- Both data points are valuable for trip analysis

### Visual Distinction
- **Existing markers**: Orange circles with numbers (actual route delivery points from waypoints)
- **New delivery destination markers**: Purple house icons (intended delivery addresses from GetDeliveryOrder)

This allows analysts to compare if the driver visited the correct delivery location.

---

## Dependencies Identified

1. **DataDog API**: Already in use for route logs
2. **Google Maps JavaScript API**: Already in use for marker rendering
3. **Configuration system**: Already supports dynamic styling

No new external dependencies required.

---

## Verification

All research decisions verified against:
- ✅ `verify-grpc-logs.py` script confirmed logs exist for GetDeliveryOrder and GetLocationsDetails
- ✅ `grpc-enhancements-plan.md` documented expected response fields
- ✅ Existing codebase patterns reviewed (DataDogClient, MapGenerator, Configuration)
- ✅ User clarifications integrated from spec.md Session 2025-12-08

