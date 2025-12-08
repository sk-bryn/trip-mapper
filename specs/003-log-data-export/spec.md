# Feature Specification: Log Data Export

**Feature Branch**: `003-log-data-export`
**Created**: 2025-12-08
**Status**: Draft
**Input**: User description: "A new output file to show the data from the original logs pulled from datadog that would be created and stored alongside the map outputs, so the log data can be independently verified against the rendered map"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Export Raw Log Data for Verification (Priority: P1)

As a trip analyst, I need to see the original log data that was used to generate a trip map, so that I can independently verify the rendered route matches the source data from DataDog.

**Why this priority**: This is the core use case. Without access to source log data, analysts cannot verify that the visualization accurately represents the raw data, making it impossible to trust the output for auditing or debugging purposes.

**Independent Test**: Can be fully tested by running the visualizer on any tripId and verifying that a data export file is created alongside the map outputs containing the original log information.

**Acceptance Scenarios**:

1. **Given** a tripId with log data in DataDog, **When** I request visualization of that tripId, **Then** a data export file is created in the output directory alongside the map files.

2. **Given** a tripId with multiple log fragments, **When** I request visualization, **Then** the single data export file contains all route segments with their correlated DataDog log entries, timestamps, and waypoint counts.

3. **Given** the generated map and the data export file, **When** I compare them, **Then** I can trace each route segment on the map to its corresponding DataDog log entry and see the orderIds delivered in that segment.

---

### User Story 2 - Human-Readable Export Format (Priority: P1)

As a trip analyst, I need the exported log data to be in a human-readable format, so that I can review it without specialized tools.

**Why this priority**: Equal priority with Story 1 because an export file that requires specialized parsing tools defeats the purpose of independent verification.

**Independent Test**: Can be fully tested by opening the exported data file in a standard text editor and verifying all data is readable and understandable.

**Acceptance Scenarios**:

1. **Given** an exported data file, **When** I open it in a text editor, **Then** I can read the trip ID, timestamps, route segment summaries, and orderIds without additional processing.

2. **Given** an exported data file from a multi-log trip, **When** I review the file, **Then** each route segment is clearly delineated with its correlated DataDog log metadata (timestamp, waypoint count, log ID, orderIds).

3. **Given** an exported data file, **When** I review the structure, **Then** I can see the ordered sequence of orderIds across the entire trip and waypoint counts per segment and per orderId.

---

### User Story 3 - Include DataDog Reference Links (Priority: P2)

As a trip analyst, I need the exported data to include links back to the original DataDog log entries, so that I can quickly navigate to the source logs for deeper investigation.

**Why this priority**: Lower priority than core export functionality, but valuable for workflows that require drilling down into the original log context in DataDog.

**Independent Test**: Can be fully tested by opening the data export file, finding a DataDog link, and clicking it to verify it opens the correct log entry.

**Acceptance Scenarios**:

1. **Given** an exported data file, **When** I review the log fragment entries, **Then** each fragment includes a clickable URL to view that log in the DataDog console.

2. **Given** a DataDog link from the export file, **When** I navigate to it, **Then** I am taken directly to the specific log entry that contains the route data.

---

### Edge Cases

- What happens when log data contains special characters or unusual coordinate formats? (Export preserves original data exactly as received from DataDog)
- How does the system handle extremely large trips with thousands of waypoints? (Export file is created regardless of size; large files may take longer to write)
- What happens if the export file cannot be written due to permissions? (System reports error but still generates map outputs if possible)
- How does the export handle trips where some log fragments failed to download? (Export includes only successfully retrieved logs, with a note indicating missing data)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST automatically create a data export file for every trip visualization, with no option to disable; stored in the same output directory as the map files.
- **FR-002**: System MUST include the trip ID in the export file, matching the ID used for map generation.
- **FR-003**: System MUST export a summary waypoint count for each route segment (not individual waypoint coordinates, for brevity).
- **FR-004**: System MUST include the timestamp of each log fragment in the export.
- **FR-005**: System MUST include the DataDog log ID for each fragment to enable cross-reference.
- **FR-006**: System MUST include a clickable DataDog URL for each log fragment.
- **FR-007**: System MUST clearly separate multiple log fragments in the export file with visible delimiters or structure.
- **FR-008**: System MUST use pretty-printed JSON format (indented for readability) that can be opened in standard text editors and parsed by automated tools.
- **FR-009**: System MUST include summary metadata showing total log count and total waypoint count.
- **FR-010**: System MUST indicate in the export if any log fragments failed to download or were truncated.
- **FR-011**: System MUST name the export file using the trip ID for easy association with map outputs.
- **FR-012**: System MUST clearly specify which DataDog log entry correlates to which individual route segment.
- **FR-013**: System MUST identify the orderIds that correspond to each route segment.
- **FR-014**: System MUST indicate the correct ordered sequence of orderIds across the trip.
- **FR-015**: System MUST include a waypoint count per orderId where orderIds are present in the source data.

### Key Entities

- **Log Data Export**: A single JSON file containing all DataDog log details for a trip visualization. Contains: trip ID, generation timestamp, route segments with log correlations, ordered sequence of orderIds, summary statistics.
- **Route Segment Entry**: A section within the export representing one route segment. Contains: segment index, correlated DataDog log ID, DataDog URL, timestamp, waypoint count, list of orderIds with their waypoint counts.
- **Order Summary**: Aggregated information about an orderId within a route segment. Contains: orderId, waypoint count for that order.
- **OrderId Sequence**: The complete ordered list of all orderIds across the entire trip, showing delivery sequence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every trip visualization produces a corresponding data export file in the output directory.
- **SC-002**: Users can open the export file in any standard text editor and read all data without additional tools.
- **SC-003**: Every route segment shown on the rendered map can be traced to a specific DataDog log entry in the export file with waypoint count and orderIds.
- **SC-004**: DataDog links in the export file successfully navigate to the correct log entries.
- **SC-005**: Multi-log trip exports clearly show the boundary between each route segment.
- **SC-006**: The export file shows the complete ordered sequence of orderIds, allowing verification of delivery order.

## Clarifications

### Session 2025-12-08

- Q: Should export generation be configurable or always automatic? → A: Always generate export file automatically (no user control)
- Q: What format should the export file use? → A: JSON with pretty-printing (indented, human-readable)
- Q: Should there be one export file or one per segment? → A: One single data file containing all DataDog log details
- Q: Should individual waypoints be listed? → A: No, use summary waypoint counts per route segment and per orderId for brevity
- Q: What correlations should the export show? → A: DataDog log entry to route segment mapping; orderIds per route segment; ordered sequence of orderIds

## Assumptions

- The export file format will be JSON, which is both human-readable (when formatted) and machine-parseable for automated verification workflows.
- Export file naming will follow the pattern `<tripId>-data.json` to match existing output conventions.
- The export is generated automatically as part of the visualization process, not as a separate command.
- Export generation does not block or delay map generation; both outputs are produced in the same run.
- OrderIds are extracted from the waypoint data where present; waypoints without orderIds are counted but not associated with a specific order.
- Route segments correspond to log fragments from the multi-log trip support feature (002-multi-log-trips).
