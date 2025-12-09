# Data Model: Order & Location Enrichment

**Feature**: 004-order-location-enrichment
**Date**: 2025-12-08

## Overview

This document defines the data entities for the Order & Location Enrichment feature. All entities are strongly-typed Swift structs following existing codebase patterns.

---

## New Entities

### DeliveryDestination

The delivery dropoff location for an order, extracted from GetDeliveryOrder logs.

```swift
/// Represents the intended delivery destination for an order.
///
/// This entity contains the address and coordinates where an order
/// should be delivered, distinct from the actual route waypoints
/// showing where the driver traveled.
public struct DeliveryDestination: Codable, Equatable, Sendable {
    /// The order identifier
    public let orderId: UUID

    /// Full concatenated address string
    /// Example: "123 Main St, Apt #2, Atlanta, GA, 30301"
    public let address: String

    /// Street address portion
    /// Example: "123 Main St, Apt #2"
    public let addressDisplayLine1: String

    /// City, state, zip portion
    /// Example: "Atlanta, GA, 30301"
    public let addressDisplayLine2: String

    /// Delivery coordinates
    public let latitude: Double
    public let longitude: Double

    /// Optional dropoff instructions
    public let dropoffInstructions: String?
}
```

**Source**: DataDog logs with `"handled request for GetDeliveryOrder"`

**Validation Rules**:
- `orderId` must be a valid UUID
- `latitude` must be in range [-90, 90]
- `longitude` must be in range [-180, 180]
- `address` must not be empty

---

### RestaurantLocation

The restaurant origin point for a trip, extracted from GetLocationsDetails logs.

```swift
/// Represents a restaurant location where delivery trips originate.
///
/// Contains the restaurant name, address, and coordinates for
/// displaying the trip origin on visualizations.
public struct RestaurantLocation: Codable, Equatable, Sendable {
    /// 5-digit location identifier
    /// Example: "00070"
    public let locationNumber: String

    /// Restaurant name
    /// Example: "West Columbia"
    public let name: String

    /// Street address line 1
    public let address1: String

    /// Optional street address line 2 (suite, unit)
    public let address2: String?

    /// City name
    public let city: String

    /// State code (2 letters)
    public let state: String

    /// ZIP code
    public let zip: String

    /// Restaurant coordinates
    public let latitude: Double
    public let longitude: Double

    /// Optional operator name
    public let operatorName: String?

    /// Optional timezone identifier
    /// Example: "America/New_York"
    public let timeZone: String?
}
```

**Source**: DataDog logs with `"handled request for GetLocationsDetails"`

**Validation Rules**:
- `locationNumber` must be exactly 5 digits
- `latitude` must be in range [-90, 90]
- `longitude` must be in range [-180, 180]
- `name`, `address1`, `city`, `state`, `zip` must not be empty

**Computed Properties**:
```swift
extension RestaurantLocation {
    /// Full formatted address string
    public var formattedAddress: String {
        var parts = [address1]
        if let address2 = address2, !address2.isEmpty {
            parts.append(address2)
        }
        parts.append("\(city), \(state) \(zip)")
        return parts.joined(separator: ", ")
    }
}
```

---

### EnrichmentStatus

Status flags indicating whether enrichment data was found.

```swift
/// Status indicators for enrichment data availability.
///
/// Always included in map-data.json to indicate whether order
/// and location enrichment data was successfully retrieved.
public struct EnrichmentStatus: Codable, Equatable, Sendable {
    /// True if at least one order's delivery address was found
    public let orderDataFound: Bool

    /// True if restaurant location was found
    public let locationDataFound: Bool
}
```

**Source**: Computed during enrichment processing

**JSON Output Example**:
```json
{
  "orderDataFound": true,
  "locationDataFound": false
}
```

---

### EnrichmentResult

Combined result of fetching all enrichment data for a trip.

```swift
/// Aggregated enrichment data for a trip visualization.
///
/// Contains restaurant location (if available), delivery destinations
/// for orders (may be partial), and status/warning information.
public struct EnrichmentResult: Codable, Equatable, Sendable {
    /// Restaurant location (nil if not found)
    public let restaurantLocation: RestaurantLocation?

    /// Delivery destinations for orders (may be empty or partial)
    public let deliveryDestinations: [DeliveryDestination]

    /// Status flags for export
    public let status: EnrichmentStatus

    /// Warning messages for failed lookups
    public let warnings: [String]
}
```

**Factory Method**:
```swift
extension EnrichmentResult {
    /// Creates an empty result for when enrichment is skipped or fails completely
    public static var empty: EnrichmentResult {
        EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: false),
            warnings: []
        )
    }
}
```

---

### MarkerStyle

Configuration for marker visual appearance.

```swift
/// Visual style configuration for map markers.
public struct MarkerStyle: Codable, Equatable, Sendable {
    /// Icon identifier (e.g., "home", "restaurant", "circle")
    public let icon: String

    /// Hex color without # prefix (e.g., "9900FF")
    public let color: String
}
```

**Source**: Configuration file

**Default Values**:
```swift
extension MarkerStyle {
    /// Default style for delivery destination markers
    public static let defaultDeliveryDestination = MarkerStyle(
        icon: "home",
        color: "9900FF"
    )

    /// Default style for restaurant origin markers
    public static let defaultRestaurantOrigin = MarkerStyle(
        icon: "restaurant",
        color: "0066FF"
    )
}
```

---

## Modified Entities

### TripDataExport (Modified)

Add enrichment data to the existing export structure.

**New Fields**:
```swift
extension TripDataExport {
    /// Restaurant location details (nil if not available)
    public let restaurantLocation: RestaurantLocation?

    /// Delivery destinations for orders
    public let deliveryDestinations: [DeliveryDestination]

    /// Enrichment status indicators (always present)
    public let enrichmentStatus: EnrichmentStatus

    /// Enrichment warning messages
    public let enrichmentWarnings: [String]
}
```

**Updated JSON Structure**:
```json
{
  "tripId": "uuid-string",
  "generatedAt": "2025-12-08T10:30:00Z",
  "summary": { ... },
  "orderSequence": ["order-uuid-1", "order-uuid-2"],
  "routeSegments": [ ... ],
  "restaurantLocation": {
    "locationNumber": "00070",
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
      "orderId": "order-uuid-1",
      "address": "123 Main St, Atlanta, GA, 30301",
      "addressDisplayLine1": "123 Main St",
      "addressDisplayLine2": "Atlanta, GA, 30301",
      "latitude": 33.7490,
      "longitude": -84.3880
    }
  ],
  "enrichmentStatus": {
    "orderDataFound": true,
    "locationDataFound": true
  },
  "enrichmentWarnings": []
}
```

---

### Configuration (Modified)

Add marker style configuration.

**New Fields**:
```swift
extension Configuration {
    /// Marker style for delivery destination markers
    public var deliveryDestinationMarkerStyle: MarkerStyle

    /// Marker style for restaurant origin markers
    public var restaurantOriginMarkerStyle: MarkerStyle
}
```

**Configuration File Addition**:
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

## Entity Relationships

```
TripDataExport
├── ExportSummary (existing)
├── [RouteSegmentExport] (existing)
├── RestaurantLocation? (NEW)
├── [DeliveryDestination] (NEW)
└── EnrichmentStatus (NEW)

EnrichmentResult
├── RestaurantLocation?
├── [DeliveryDestination]
├── EnrichmentStatus
└── [String] warnings

Configuration
├── ... (existing fields)
├── MarkerStyle deliveryDestinationMarkerStyle (NEW)
└── MarkerStyle restaurantOriginMarkerStyle (NEW)
```

---

## State Transitions

### EnrichmentResult Lifecycle

```
┌─────────────────┐
│   Not Started   │
└────────┬────────┘
         │ fetchEnrichmentData()
         ▼
┌─────────────────┐
│   Fetching      │ ── parallel queries ──►
└────────┬────────┘
         │ queries complete
         ▼
┌─────────────────────────────────────┐
│   Complete                          │
│   (may be partial/empty)            │
│   - restaurantLocation: found/nil   │
│   - deliveryDestinations: 0..N      │
│   - status: computed from results   │
│   - warnings: accumulated errors    │
└─────────────────────────────────────┘
```

---

## Validation Summary

| Entity | Field | Rule |
|--------|-------|------|
| DeliveryDestination | orderId | Valid UUID |
| DeliveryDestination | latitude | [-90, 90] |
| DeliveryDestination | longitude | [-180, 180] |
| DeliveryDestination | address | Non-empty |
| RestaurantLocation | locationNumber | 5 digits |
| RestaurantLocation | latitude | [-90, 90] |
| RestaurantLocation | longitude | [-180, 180] |
| RestaurantLocation | name, city, state | Non-empty |
| MarkerStyle | color | 6-char hex |

