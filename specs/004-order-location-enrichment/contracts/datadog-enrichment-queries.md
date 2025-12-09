# DataDog Enrichment Query Contracts

**Feature**: 004-order-location-enrichment
**Date**: 2025-12-08

## Overview

This document defines the DataDog log query contracts for fetching enrichment data. These contracts specify the query patterns, expected response structures, and parsing rules.

---

## 1. GetDeliveryOrder Query

### Purpose
Fetch delivery address and coordinates for a specific orderId.

### Query Pattern
```
env:{datadogEnv} @trip_id:{tripId} service:{datadogService} "handled request for GetDeliveryOrder"
```

### Parameters
| Parameter | Source | Example |
|-----------|--------|---------|
| datadogEnv | Configuration.datadogEnv | "prod" |
| tripId | Input tripId | "a1b2c3d4-..." |
| datadogService | Configuration.datadogService | "delivery-driver-service" |

### Expected Response Structure
```json
{
  "data": [
    {
      "id": "log-id",
      "type": "log",
      "attributes": {
        "timestamp": "2025-12-08T10:30:00Z",
        "message": "handled request for GetDeliveryOrder",
        "attributes": {
          "response_body": {
            "order": {
              "orderID": "order-uuid",
              "coordinates": {
                "latitude": 33.7490,
                "longitude": -84.3880
              },
              "address": "123 Main St, Atlanta, GA, 30301",
              "addressDisplayLine1": "123 Main St",
              "addressDisplayLine2": "Atlanta, GA, 30301"
            }
          }
        }
      }
    }
  ]
}
```

### Parsing Rules
1. Extract `order` object from `attributes.attributes.response_body`
2. Map `orderID` to UUID (validate format)
3. Map `coordinates.latitude` and `coordinates.longitude` to Double
4. Map address fields directly
5. If parsing fails, log warning and skip this order

### Error Handling
| Scenario | Action |
|----------|--------|
| No logs found | Set orderDataFound=false, continue |
| Parsing error | Log warning, skip order |
| Network timeout | Retry per configuration, then skip |

---

## 2. GetLocationsDetails Query

### Purpose
Fetch restaurant name, address, and coordinates for a location_number.

### Query Pattern
```
env:{datadogEnv} service:{datadogService} "handled request for GetLocationsDetails"
```

Note: This query does not include tripId because GetLocationsDetails uses location_number as input.

### Parameters
| Parameter | Source | Example |
|-----------|--------|---------|
| datadogEnv | Configuration.datadogEnv | "prod" |
| datadogService | Configuration.datadogService | "delivery-driver-service" |

### Additional Filtering
After fetching logs, filter by location_number in the response body or request parameters to find the relevant restaurant.

### Expected Response Structure
```json
{
  "data": [
    {
      "id": "log-id",
      "type": "log",
      "attributes": {
        "timestamp": "2025-12-08T10:30:00Z",
        "message": "handled request for GetLocationsDetails",
        "attributes": {
          "response_body": {
            "locations": [
              {
                "locationNumber": "00070",
                "name": "West Columbia",
                "coordinates": {
                  "latitude": 33.98325,
                  "longitude": -81.096
                },
                "address": {
                  "address1": "2299 Augusta Rd",
                  "address2": "",
                  "city": "West Columbia",
                  "state": "SC",
                  "zip": "29169"
                },
                "operatorName": "Operator Name",
                "timeZone": "America/New_York"
              }
            ]
          }
        }
      }
    }
  ]
}
```

### Parsing Rules
1. Extract `locations` array from `attributes.attributes.response_body`
2. Find location matching target `location_number`
3. Map all fields to RestaurantLocation struct
4. Optional fields (address2, operatorName, timeZone) may be null/empty

### Error Handling
| Scenario | Action |
|----------|--------|
| No logs found | Set locationDataFound=false, continue |
| Location not in response | Log warning, set locationDataFound=false |
| Parsing error | Log warning, set locationDataFound=false |

---

## 3. DataDog Request Contract

### HTTP Request
```http
POST /api/v2/logs/events/search HTTP/1.1
Host: api.datadoghq.com
Content-Type: application/json
DD-API-KEY: {DD_API_KEY}
DD-APPLICATION-KEY: {DD_APP_KEY}

{
  "filter": {
    "query": "{query_string}",
    "from": "now-30d",
    "to": "now"
  },
  "sort": "timestamp",
  "page": {
    "limit": 10
  }
}
```

### Time Range
Use same time range as route log queries (`now-30d` to `now`) per FR-011.

### Rate Limiting
- Standard DataDog API rate limits apply
- Use existing retry logic with exponential backoff
- Handle 429 responses gracefully

---

## 4. Swift Protocol Definition

```swift
/// Protocol for enrichment data fetching
public protocol EnrichmentFetching {
    /// Fetches delivery destination for an order
    /// - Parameters:
    ///   - orderId: The order UUID
    ///   - tripId: The trip UUID (for query filtering)
    /// - Returns: DeliveryDestination or nil if not found
    func fetchDeliveryDestination(
        orderId: UUID,
        tripId: UUID
    ) async throws -> DeliveryDestination?

    /// Fetches restaurant location by location number
    /// - Parameter locationNumber: 5-digit location identifier
    /// - Returns: RestaurantLocation or nil if not found
    func fetchRestaurantLocation(
        locationNumber: String
    ) async throws -> RestaurantLocation?

    /// Fetches all enrichment data for a trip
    /// - Parameters:
    ///   - tripId: The trip UUID
    ///   - orderIds: Array of order UUIDs to enrich
    ///   - locationNumber: Restaurant location number (optional)
    /// - Returns: Combined enrichment result
    func fetchEnrichmentData(
        tripId: UUID,
        orderIds: [UUID],
        locationNumber: String?
    ) async -> EnrichmentResult
}
```

---

## 5. Response Validation Contract

### DeliveryDestination Validation
```swift
struct DeliveryDestinationValidator {
    static func validate(_ data: [String: Any]) -> Bool {
        guard let orderID = data["orderID"] as? String,
              UUID(uuidString: orderID) != nil,
              let coords = data["coordinates"] as? [String: Any],
              let lat = coords["latitude"] as? Double,
              let lng = coords["longitude"] as? Double,
              let address = data["address"] as? String,
              !address.isEmpty,
              lat >= -90, lat <= 90,
              lng >= -180, lng <= 180
        else { return false }
        return true
    }
}
```

### RestaurantLocation Validation
```swift
struct RestaurantLocationValidator {
    static func validate(_ data: [String: Any]) -> Bool {
        guard let locationNumber = data["locationNumber"] as? String,
              locationNumber.count == 5,
              locationNumber.allSatisfy({ $0.isNumber }),
              let name = data["name"] as? String,
              !name.isEmpty,
              let coords = data["coordinates"] as? [String: Any],
              let lat = coords["latitude"] as? Double,
              let lng = coords["longitude"] as? Double,
              lat >= -90, lat <= 90,
              lng >= -180, lng <= 180
        else { return false }
        return true
    }
}
```

