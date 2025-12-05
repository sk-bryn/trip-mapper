# Feature Specification: Trip Route Visualizer CLI

**Feature Branch**: `001-trip-route-visualizer`
**Created**: 2025-12-04
**Status**: Draft
**Input**: User description: "Swift CLI tool to visualize driver trip routes by plotting route segments extracted from trip logs on a Google Map. Accepts trip identifier, fetches logs from external service, extracts route segments, outputs final image and/or Google Map link. Runs entirely headless on CLI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Visualize Trip Route (Priority: P1)

As a support engineer or operations analyst, I want to enter a trip identifier and receive a visual map showing the complete route taken by the driver, so I can investigate delivery issues, verify routes, or analyze driver behavior.

**Why this priority**: This is the core value proposition of the tool. Without the ability to visualize a trip route, the tool has no purpose.

**Independent Test**: Can be fully tested by providing a valid trip identifier and verifying that the output contains a map visualization with plotted waypoints representing the driver's route.

**Acceptance Scenarios**:

1. **Given** a valid trip identifier exists in the logging service, **When** the user runs the CLI with that trip identifier, **Then** the system outputs a map visualization showing all route segments as a connected polyline.

2. **Given** a valid trip identifier with multiple route segments, **When** the user runs the CLI, **Then** all segments are plotted in chronological order showing the complete journey from start to finish.

3. **Given** a trip identifier, **When** the visualization completes, **Then** the user receives either a static map image file, a Google Maps link, or both (based on configuration).

---

### User Story 2 - Handle Invalid or Missing Trips (Priority: P2)

As a user, I want clear feedback when a trip cannot be found or has no route data, so I can correct my input or investigate why data is missing.

**Why this priority**: Error handling is essential for a usable tool, but secondary to the core visualization functionality.

**Independent Test**: Can be tested by providing invalid, malformed, or non-existent trip identifiers and verifying appropriate error messages are displayed.

**Acceptance Scenarios**:

1. **Given** a trip identifier that does not exist in the logging service, **When** the user runs the CLI, **Then** the system displays a clear error message indicating the trip was not found.

2. **Given** a trip identifier with no route segment data in the logs, **When** the user runs the CLI, **Then** the system displays a message indicating no route data is available for visualization.

3. **Given** a malformed trip identifier, **When** the user runs the CLI, **Then** the system displays a validation error with the expected format.

---

### User Story 3 - View Progress During Processing (Priority: P3)

As a user running the tool on a trip with many log entries, I want to see progress indicators during long-running operations, so I know the tool is working and can estimate completion time.

**Why this priority**: Progress feedback improves user experience but is not essential for core functionality.

**Independent Test**: Can be tested by processing a trip with substantial log data and verifying progress updates are displayed during fetching and processing phases.

**Acceptance Scenarios**:

1. **Given** the user runs the CLI with a valid trip identifier, **When** the system begins fetching logs, **Then** a progress indicator shows the fetch operation is in progress.

2. **Given** a trip with many log entries, **When** processing takes more than a few seconds, **Then** the user sees incremental progress updates.

---

### User Story 4 - Configure Output Format (Priority: P3)

As a user, I want to choose the output format (image file, map link, or both), so I can use the visualization in my preferred way.

**Why this priority**: Output flexibility enhances usability but the tool can function with a single default output format.

**Independent Test**: Can be tested by specifying different output options and verifying the corresponding outputs are generated.

**Acceptance Scenarios**:

1. **Given** the user specifies image output, **When** the CLI completes, **Then** a static map image file is saved to the specified location.

2. **Given** the user specifies link output, **When** the CLI completes, **Then** a Google Maps URL is displayed showing the route.

3. **Given** no output preference specified, **When** the CLI completes, **Then** the default output format is used (configurable via config file).

---

### Edge Cases

- **Single waypoint**: System displays an error message explaining that a route requires at least 2 waypoints to visualize.
- **Multiple logs returned**: System displays an error message indicating data integrity issue (expected exactly one log per trip).
- **Missing order_id**: Waypoint is treated as return-to-restaurant segment (valid, not an error).
- **Large geographic areas**: Google Maps auto-zooms to fit all waypoints; very large spans may result in less detail but route remains visible.
- **Logging service unavailable**: System retries with exponential backoff (FR-015), then fails with clear error message after max retries exceeded.
- **Invalid/missing coordinates**: Waypoints with invalid or missing latitude/longitude are skipped with a warning logged; processing continues with valid waypoints.
- **API rate limits exceeded**: System displays error message indicating rate limit and suggests waiting before retry.
- **Thousands of waypoints**: System uses polyline encoding to compress path data; performance target is <30s for 500 waypoints (SC-001). Trips exceeding this may take longer but will complete.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST accept a trip identifier as a required command-line argument.
- **FR-002**: System MUST fetch the log entry for the specified trip identifier from the external logging service. Exactly one log is expected per trip.
- **FR-003**: System MUST extract route segment data (geographic coordinates) from the fetched log entries.
- **FR-004**: System MUST plot extracted waypoints as a connected polyline on a Google Map visualization.
- **FR-005**: System MUST output the visualization as a static image file (PNG format).
- **FR-006**: System MUST output a Google Maps URL that displays the route.
- **FR-007**: System MUST display clear error messages to stderr when operations fail.
- **FR-008**: System MUST display progress indicators for operations taking longer than 2 seconds.
- **FR-009**: System MUST provide a help command showing usage instructions and available options.
- **FR-010**: System MUST log all operations to a timestamped log file (`<tripId>-<timestamp>.log`).
- **FR-011**: System MUST read API credentials from environment variables (never from command-line arguments or hardcoded values).
- **FR-012**: System MUST support configuration via a configuration file for customizable settings.
- **FR-013**: System MUST allow users to specify the output directory for generated files.
- **FR-014**: System MUST validate the trip identifier as a valid UUID format before making external service calls.
- **FR-015**: System MUST handle network timeouts gracefully with appropriate retry logic.
- **FR-016**: System MUST fail with an error if more than one log entry is returned for a given trip identifier.
- **FR-017**: System MUST store the source log ID and log link within the Trip data for reference.
- **FR-018**: System MUST query DataDog using the following filters: `env:<environment>`, `@trip_id:<uuid>`, `service:<service-name>`, and content containing `"received request for SaveActualRouteForTrip"`.
- **FR-019**: System MUST read default values for `env` (prod/test) and `service` (e.g., `delivery-driver-service`) from the configuration file.

### Key Entities

- **Trip**: A delivery journey identified by a unique trip identifier (UUID). Contains the source log ID and log link for reference. Each trip maps to exactly one log entry in the logging service.
- **Waypoint**: A point along the route extracted from the `segment_coords` array. Contains:
  - `coordinates.latitude` (Float): Latitude coordinate
  - `coordinates.longitude` (Float): Longitude coordinate
  - `order_id` (UUID, optional): The order being delivered during this segment. If absent, indicates the driver is returning to the originating restaurant.
- **Visualization Output**: The generated map representation, available as a static image file and/or interactive map URL.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can generate a trip route visualization within 30 seconds for trips with up to 500 waypoints.
- **SC-002**: 95% of valid trip identifiers result in successful visualization generation.
- **SC-003**: Error messages clearly indicate the cause of failure, enabling users to resolve issues without external support.
- **SC-004**: Users can successfully use the tool after reading only the help output (no external documentation required for basic usage).
- **SC-005**: Generated map visualizations accurately represent the chronological route taken by the driver.
- **SC-006**: The tool runs successfully on both macOS and Linux operating systems without modification.

## Clarifications

### Session 2025-12-04

- Q: How are coordinates structured within the logs? → A: JSON object with `segment_coords` array field containing objects with `coordinates` (latitude/longitude) and optional `order_id`
- Q: What happens when the trip has only a single waypoint? → A: Fail with error message explaining a route requires at least 2 points
- Q: What is the expected trip identifier format? → A: UUID format (e.g., `550e8400-e29b-41d4-a716-446655440000`)
- Q: How many logs are expected per trip? → A: Exactly one log per trip; multiple logs returned is an error condition
- Q: What does each log contain? → A: Each log contains the entire trip data; Trip entity stores log ID and link for reference
- Q: What is the waypoint data structure? → A: `segment_coords[]` with `coordinates.latitude`, `coordinates.longitude` (floats), and optional `order_id` (UUID)
- Q: What does missing order_id indicate? → A: Route segment is heading back to originating restaurant location
- Q: What are the DataDog query filters? → A: Query must include: `env:<value>` (prod/test), `@trip_id:<uuid>`, `service:<service-name>`, and content string `"received request for SaveActualRouteForTrip"`. Default `env` and `service` values come from config file; trip_id from user input.

## Assumptions

- Each trip has exactly one corresponding log entry in the logging service. Multiple logs for the same trip ID indicates a data integrity issue.
- The log contains the complete trip data in a `segment_coords` array with waypoints structured as:
  ```json
  {
    "segment_coords": [
      {
        "coordinates": { "latitude": 37.7749, "longitude": -122.4194 },
        "order_id": "optional-uuid-string"
      }
    ]
  }
  ```
- Trip identifiers are UUIDs (e.g., `550e8400-e29b-41d4-a716-446655440000`) and can be validated using standard UUID format rules.
- The `order_id` field is optional; when absent, the waypoint represents a return-to-restaurant segment.
- DataDog logs are queried using a composite filter: `env:<environment> @trip_id:<uuid> service:<service-name> "received request for SaveActualRouteForTrip"`.
- Valid `env` values are `prod` or `test` (configurable default).
- Default `service` value is `delivery-driver-service` (configurable).
- Google Maps API supports generating both static images and shareable URLs for polyline routes.
- Users have network access to both the logging service and Google Maps API.
- Environment variables for API credentials are configured before running the tool.
