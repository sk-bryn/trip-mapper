# Protocol Buffer API Research: Trip & Order Location Data

**Purpose**: Identify APIs that return street addresses and/or coordinates for orders and restaurants by their IDs.

**Source**: `/Users/bryn.trussell/Desktop/robot-jail/trip-mapper/protos/DeliveryIDL/`

---

## Summary: APIs That Return Location Data

| API Method | Service | Input | Returns Address? | Returns Coordinates? |
|------------|---------|-------|------------------|---------------------|
| **GetDeliveryOrder** | Order Service | orderID | ✅ Full address | ✅ lat/long |
| **GetTripDetails** | Order Service | tripID | ✅ Per order | ✅ Per order |
| **GetRouteDetailsForTrip** | Order Service | tripID | ❌ | ✅ Route waypoints |
| **GetLocationsDetails** | Driver Service | locationNumbers[] | ✅ Restaurant address | ✅ Restaurant coords |
| **GetDeliveryDriverByID** | Driver Service | driverID | ❌ | ✅ Current location |

---

## ORDER LOCATION APIs

### 1. GetDeliveryOrder
**Best for**: Getting address/coordinates for a single order by orderId

```
Service: Cfa_Delivery_Order_V1_DeliveryOrderServiceClient
File: cfa_delivery_order_v1_order_service.connect.swift
```

**Input**: `Cfa_Delivery_Order_V1_GetDeliveryOrderRequest`
- `orderID: String` - The order UUID

**Output**: `Cfa_Delivery_Order_V1_GetDeliveryOrderResponse`
- `order.coordinates.latitude: Float`
- `order.coordinates.longitude: Float`
- `order.address: String` - Full concatenated address (e.g., "123 Main St, Apt #2, New York, NY, 10001")
- `order.addressDisplayLine1: String` - Street address
- `order.addressDisplayLine2: String` - City, state, zip

---

### 2. GetTripDetails
**Best for**: Getting all orders in a trip with their addresses/coordinates

```
Service: Cfa_Delivery_Order_V1_DeliveryOrderServiceClient
File: cfa_delivery_order_v1_order_service.connect.swift
```

**Input**: `Cfa_Delivery_Order_V1_GetTripDetailsRequest`
- `tripID: String` - The trip UUID

**Output**: `Cfa_Delivery_Order_V1_GetTripDetailsResponse`
- `tripID: String`
- `orders: [DeliveryOrder]` - Each order contains:
  - `orderID: String`
  - `coordinates.latitude: Float`
  - `coordinates.longitude: Float`
  - `address: String` - Full delivery address
  - `priority: Int32` - Sequence in trip (1st stop, 2nd stop, etc.)
- `startTime: Timestamp`
- `endTime: Timestamp`
- `totalTripDistanceMeters: Int32`

---

### 3. GetRouteDetailsForTrip
**Best for**: Getting actual GPS route waypoints (not just destinations)

```
Service: Cfa_Delivery_Order_V1_DeliveryOrderServiceClient
File: cfa_delivery_order_v1_order_service.connect.swift
```

**Input**: `Cfa_Delivery_Order_V1_GetRouteDetailsForTripRequest`
- `tripID: String`

**Output**: `Cfa_Delivery_Order_V1_GetRouteDetailsForTripResponse`
- `routeSegments: [RouteSegment]` - Each segment contains:
  - `routeID: String` - Order/batch ID
  - `priority: Int32` - Delivery sequence
  - `planned: [Coordinates]` - Planned route waypoints
  - `actual: [Coordinates]` - Actual driver route waypoints
- `returnRoute.planned: [Coordinates]`
- `returnRoute.actual: [Coordinates]`
- `driverID: String`

---

## RESTAURANT/LOCATION APIs

### 4. GetLocationsDetails ⭐ KEY API
**Best for**: Getting restaurant address/coordinates by location_number

```
Service: Cfa_Delivery_Driver_V1_DeliveryDriverServiceClient
File: cfa_delivery_driver_v1_driver_service.connect.swift
```

**Input**: `Cfa_Delivery_Driver_V1_GetLocationsDetailsRequest`
- `locationNumbers: [String]` - Array of 5-digit location numbers (e.g., ["00070", "02345"])

**Output**: `Cfa_Delivery_Driver_V1_GetLocationsDetailsResponse`
- `locations: [Cfa_Delivery_Core_V1_Location]` - Each location contains:
  - `locationNumber: String` - 5-digit identifier
  - `name: String` - Restaurant name (e.g., "West Columbia")
  - `coordinates.latitude: Float`
  - `coordinates.longitude: Float`
  - `address.address1: String` - Street (e.g., "2299 Augusta Rd")
  - `address.address2: String` - Optional suite/unit
  - `address.city: String`
  - `address.state: String`
  - `address.zip: String`
  - `operatorName: String` - Restaurant operator name
  - `timeZone: String` - e.g., "America/New_York"
- `locationDetailsErrors: [LocationDetailsError]` - Any lookup failures

---

## DRIVER LOCATION API

### 5. GetDeliveryDriverByID
**Best for**: Getting current driver GPS location

```
Service: Cfa_Delivery_Driver_V1_DeliveryDriverServiceClient
File: cfa_delivery_driver_v1_driver_service.connect.swift
```

**Input**: `Cfa_Delivery_Driver_V1_GetDeliveryDriverByIdRequest`
- `driverID: String`

**Output**: `Cfa_Delivery_Driver_V1_GetDeliveryDriverByIdResponse`
- `driver.coordinates.latitude: Float` - Current location
- `driver.coordinates.longitude: Float`
- `driver.driverStatus: DriverStatus` - AT_RESTAURANT, EN_ROUTE, RETURNING
- `driver.assignedOrders: [DeliveryOrder]` - Current assignments
- `driver.etaToNextStop: Timestamp`

---

## DATA STRUCTURES

### Cfa_Delivery_Core_V1_Coordinates
```swift
struct Coordinates {
    var latitude: Float   // e.g., 33.98325
    var longitude: Float  // e.g., -81.096
}
```
File: `cfa_delivery_core_v1_coordinates.pb.swift`

### Cfa_Delivery_Core_V1_Location
```swift
struct Location {
    var locationNumber: String  // "00070"
    var name: String            // "West Columbia"
    var address: Address        // Nested address struct
    var coordinates: Coordinates
    var operatorName: String
    var timeZone: String
}
```
File: `cfa_delivery_core_v1_location.pb.swift`

### Cfa_Delivery_Core_V1_DeliveryAddress
```swift
struct DeliveryAddress {
    var address1: String  // "2299 Augusta Rd"
    var address2: String  // "Suite 100" (optional)
    var address3: String  // "Door A" (optional)
    var city: String
    var state: String     // "SC"
    var zip: String       // "29169"
    var placeID: String   // Google Places ID
}
```
File: `cfa_delivery_core_v1_delivery_address.pb.swift`

---

## RECOMMENDED USAGE FOR TRIP VISUALIZER

To enrich trip visualizations with address data:

1. **Get order addresses**: Call `GetTripDetails(tripID)` → Returns all orders with coordinates and full addresses

2. **Get restaurant location**: Call `GetLocationsDetails([locationNumber])` → Returns restaurant coordinates and street address

3. **Get route waypoints**: Already using DataDog logs with `segment_coords`, but `GetRouteDetailsForTrip(tripID)` provides the same data via gRPC

---

## FILES REFERENCE

| File | Contains |
|------|----------|
| `cfa_delivery_order_v1_order_service.connect.swift` | Order service client interface |
| `cfa_delivery_order_v1_order_service.pb.swift` | Order request/response messages |
| `cfa_delivery_driver_v1_driver_service.connect.swift` | Driver service client interface |
| `cfa_delivery_driver_v1_driver_service.pb.swift` | Driver/location messages |
| `cfa_delivery_core_v1_location.pb.swift` | Location model |
| `cfa_delivery_core_v1_coordinates.pb.swift` | Coordinates model |
| `cfa_delivery_core_v1_delivery_address.pb.swift` | Address model |
