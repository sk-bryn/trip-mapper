# Feature Specification: Order & Location Enrichment

**Feature Branch**: `004-order-location-enrichment`
**Created**: 2025-12-08
**Status**: Draft
**Input**: User description: "Gather additional data about restaurant location, order delivery dropoff locations from additional log messages found in Datadog: GetDeliveryOrder for order details; and GetLocationsDetails for restaurant location details"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Delivery Dropoff Addresses on Map (Priority: P1)

As a trip analyst, I need to see the actual delivery dropoff addresses for each order on the trip visualization, so that I can verify the driver route makes sense for the delivery destinations and identify any routing anomalies.

**Why this priority**: The primary value of this feature is enriching trip visualizations with meaningful location context. Without delivery addresses, the map shows only GPS waypoints without explaining *where* the driver was actually going.

**Independent Test**: Can be fully tested by running the visualizer on a tripId that contains orderIds, and verifying that delivery addresses appear in the map output and data export for each order.

**Acceptance Scenarios**:

1. **Given** a tripId with orders containing orderIds, **When** I request visualization, **Then** the output includes the delivery address for each orderId found in the route data.

2. **Given** an orderId present in the route waypoints, **When** the system processes the trip, **Then** it fetches the order's delivery address and coordinates from the corresponding GetDeliveryOrder log in DataDog.

3. **Given** the generated map with delivery addresses, **When** I review it, **Then** I can see distinct markers for intended delivery coordinates with address labels, visually separate from actual route waypoints, enabling comparison between where the driver was supposed to go versus where they actually drove.

---

### User Story 2 - View Restaurant Origin Location (Priority: P1)

As a trip analyst, I need to see the restaurant location (name and address) where the trip originated, so that I can verify the starting point of the delivery route and understand the full trip context.

**Why this priority**: Equal priority with Story 1 because a trip visualization without the origin point (restaurant) is incomplete. The restaurant location provides essential context for evaluating route efficiency.

**Independent Test**: Can be fully tested by running the visualizer on a tripId and verifying that the restaurant name, address, and location appear in the map output and data export.

**Acceptance Scenarios**:

1. **Given** a tripId with an associated location_number, **When** I request visualization, **Then** the output includes the restaurant name, address, and coordinates.

2. **Given** a location_number from the trip data, **When** the system processes the trip, **Then** it fetches the restaurant details from the corresponding GetLocationsDetails log in DataDog.

3. **Given** the generated map with restaurant location, **When** I review it, **Then** I can see a distinct marker or label for the restaurant origin point separate from delivery destinations.

---

### User Story 3 - Include Enriched Data in Export File (Priority: P2)

As a trip analyst, I need the delivery addresses and restaurant location to be included in the data export file, so that I can programmatically analyze trip data with full location context.

**Why this priority**: Lower priority than map visualization but essential for automated analysis workflows that consume the JSON export.

**Independent Test**: Can be fully tested by opening the map-data.json export file and verifying it contains restaurant details and delivery addresses for each order.

**Acceptance Scenarios**:

1. **Given** a completed trip visualization with enrichment data, **When** I open the map-data.json export file, **Then** I see a restaurant section with name, address, and coordinates.

2. **Given** orders with delivery addresses in the export file, **When** I review the orderSequence or route segments, **Then** each orderId includes its delivery address and coordinates.

3. **Given** the export file with enriched data, **When** I parse it programmatically, **Then** I can correlate each orderId to both its route waypoints and its final delivery destination.

---

### Edge Cases

- What happens when an orderId is found in route data but no GetDeliveryOrder log exists in DataDog? (System includes the orderId without address, with a note indicating "address unavailable")
- What happens when the location_number cannot be found in GetLocationsDetails logs? (System indicates "restaurant location unavailable" but still generates the visualization)
- How does the system handle orders with missing or malformed address data? (System includes whatever data is available, omitting missing fields)
- What happens if the enrichment data fetch fails but route data is available? (System generates the visualization with available data, logging warnings for failed enrichment)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST search DataDog for GetDeliveryOrder logs matching each orderId found in the trip route data.
- **FR-002**: System MUST extract delivery address (full address string) and coordinates (latitude, longitude) from GetDeliveryOrder logs.
- **FR-003**: System MUST search DataDog for GetLocationsDetails logs matching the trip's location_number.
- **FR-004**: System MUST extract restaurant name, address components, and coordinates from GetLocationsDetails logs.
- **FR-005**: System MUST display delivery destination markers on the generated map for orders with address data.
- **FR-006**: System MUST display the restaurant origin point as a distinct marker on the generated map.
- **FR-007**: System MUST include restaurant details in the map-data.json export file with name, address, and coordinates.
- **FR-008**: System MUST include delivery address information for each orderId in the map-data.json export file.
- **FR-009**: System MUST gracefully handle missing enrichment data without blocking visualization generation.
- **FR-010**: System MUST log warnings when enrichment data cannot be retrieved for an orderId or location_number.
- **FR-011**: System MUST use the same DataDog query time range as the existing route log search.
- **FR-012**: System MUST search for enrichment logs using the same env, service, and tripId filters as the existing route log queries, plus the function-specific filter: `"handled request for GetDeliveryOrder"` for orders.
- **FR-013**: System MUST search for enrichment logs using the same env and service filters as the existing route log queries, plus the function-specific filter: `"handled request for GetLocationsDetails"` for restaurants.
- **FR-014**: System MUST display intended delivery coordinates as distinct markers (separate from route waypoints) to enable comparison between intended destinations and actual driver path.
- **FR-015**: System MUST use both different icons AND different colors to distinguish intended delivery markers from route waypoints and restaurant origin.
- **FR-016**: System MUST allow marker styles (icons, colors) to be configurable via the existing configuration file.
- **FR-017**: System MUST continue generating all visualization artifacts (map image, HTML, URL, map-data.json) even when enrichment data is unavailable.
- **FR-018**: System MUST include an enrichment status section in map-data.json indicating whether order data was found (true/false) and whether location data was found (true/false).
- **FR-019**: System MUST include the enrichment data in map-data.json alongside existing map data when enrichment is successful.

### Key Entities

- **Delivery Destination**: The delivery dropoff location for an order. Contains: orderId, full address string, address display lines, coordinates (latitude, longitude), dropoff instructions (if available).
- **Restaurant Location**: The restaurant origin point for a trip. Contains: location_number, name, address components (address1, address2, city, state, zip), coordinates (latitude, longitude), operator name, time zone.
- **Enrichment Result**: The combined result of fetching additional location data. Contains: restaurant location (optional), delivery destinations (array, may be partial), enrichment warnings (array of failed lookups), enrichment status (orderDataFound: boolean, locationDataFound: boolean).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every trip visualization that contains orderIds shows delivery destination markers for orders where GetDeliveryOrder logs are available.
- **SC-002**: Every trip visualization shows the restaurant origin marker where GetLocationsDetails logs are available for the location_number.
- **SC-003**: The map-data.json export file includes a restaurant section with complete location details when available.
- **SC-004**: The map-data.json export file includes delivery address data for each orderId where available.
- **SC-005**: Visualization generation completes successfully even when enrichment data is partially or fully unavailable.
- **SC-006**: Users can visually distinguish between the restaurant origin, delivery destinations, and route waypoints on the generated map using distinct icons and colors for each marker type.
- **SC-007**: The map-data.json export file always includes an enrichment status section indicating whether order data and location data were found, regardless of whether enrichment succeeded or failed.

## Clarifications

### Session 2025-12-08

- Q: How should enrichment log queries be filtered? → A: Use same env, service, and tripId filters as existing route log queries to ensure data correlation.
- Q: What is the purpose of showing delivery coordinates? → A: Display intended delivery coordinates as distinct markers with address labels, allowing comparison against actual route waypoints.
- Q: How should intended delivery markers be visually distinguished from route waypoints? → A: Both different icons AND colors, with marker styles configurable.
- Q: What happens when no order or location data can be found? → A: Continue generating all artifacts (map image, HTML, URL, map-data.json). The map-data.json file MUST include status indicators noting whether order data was found and whether location data was found.

## Assumptions

- The GetDeliveryOrder and GetLocationsDetails logs are available in the same DataDog environment (env:prod) as the existing route logs.
- Location_number is available in the trip metadata or can be extracted from existing log data.
- Location_number extraction priority: (1) @location_number attribute in route logs, (2) location metadata in trip waypoints, (3) log warning if unavailable and skip restaurant enrichment.
- The DataDog query format "handled request for <FunctionName>" returns logs with response bodies containing the required data.
- Order coordinates in GetDeliveryOrder represent the delivery dropoff location, not intermediate waypoints.
- The existing map-data.json export structure can be extended to include new sections for restaurant and delivery addresses.
- Enrichment data lookup adds minimal latency to the visualization process (parallel fetching where possible).
