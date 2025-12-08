# Feature Specification: Multi-Log Trip Support

**Feature Branch**: `002-multi-log-trips`
**Created**: 2025-12-07
**Status**: Draft
**Input**: User description: "I want to handle trips that might have multiple logs. Previously only the most recent timestamped log was used, but multiple logs is a valid use-case. When the food delivery app crashes or is closed mid-trip, resuming the food delivery app will create a new log for the same trip. In these cases, each log is a fragment of the entire trip. If multiple log entries are found for a given tripId, every log should be downloaded and mapped."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Complete Trip Route After App Crash (Priority: P1)

As a trip analyst, I need to see the complete route of a trip even when the delivery driver's app crashed mid-trip, so that I can accurately assess the full journey taken.

**Why this priority**: This is the core use case. Without multi-log support, analysts see incomplete trip data when app interruptions occur, leading to inaccurate route analysis and missing waypoints.

**Independent Test**: Can be fully tested by providing a tripId that has multiple log fragments from app crashes, and verifying the output map shows all waypoints from all fragments in chronological order.

**Acceptance Scenarios**:

1. **Given** a tripId with 3 log fragments (due to 2 app crashes during the trip), **When** I request visualization of that tripId, **Then** the system downloads all 3 log fragments and generates a map showing the complete route across all fragments.

2. **Given** a tripId with log fragments that have overlapping timestamps, **When** I request visualization, **Then** the system correctly orders waypoints chronologically and removes any duplicate waypoints.

3. **Given** a tripId with multiple log fragments, **When** I request visualization, **Then** the output shows a single continuous route (not separate disconnected routes).

---

### User Story 2 - Single Log Trip Still Works (Priority: P1)

As a trip analyst, I need the system to continue working correctly for trips that have only a single log entry, so that existing workflows are not disrupted.

**Why this priority**: Equal priority with Story 1 because backward compatibility is essential. The majority of trips likely have single logs and must continue to work.

**Independent Test**: Can be fully tested by providing a tripId with exactly one log entry and verifying the output matches the current (pre-change) behavior.

**Acceptance Scenarios**:

1. **Given** a tripId with exactly 1 log entry, **When** I request visualization, **Then** the system behaves identically to the current implementation.

2. **Given** a tripId with 1 log entry, **When** I request visualization, **Then** no errors or warnings are shown about missing fragments.

---

### User Story 3 - Progress Feedback for Multi-Log Downloads (Priority: P2)

As a trip analyst running the visualizer, I want to see progress feedback when multiple logs are being downloaded, so that I understand the system is working and can estimate wait time.

**Why this priority**: Lower priority than core functionality but important for user experience, especially for trips with many fragments.

**Independent Test**: Can be fully tested by triggering visualization of a tripId with multiple logs and observing progress output.

**Acceptance Scenarios**:

1. **Given** a tripId with 5 log fragments, **When** I request visualization, **Then** the system displays progress indicating which fragment is being downloaded (e.g., "Downloading log 2 of 5...").

2. **Given** verbose mode is enabled, **When** downloading multiple log fragments, **Then** detailed information about each fragment (timestamp, size) is displayed.

---

### Edge Cases

- What happens when one log fragment fails to download but others succeed? (The system warns the user and proceeds with available data)
- How does the system handle a tripId where log fragments span multiple days? (Fragments are ordered by timestamp regardless of date)
- What happens if log fragments have gaps in the route (driver went off-grid)? (Gaps are connected with a dashed line to indicate missing data)
- How does the system handle corrupted or malformed log fragments? (Skip the corrupted fragment, warn user, continue with valid fragments)
- What happens if the total combined waypoints exceed reasonable limits? (System handles gracefully with appropriate chunking or simplification)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST fetch ALL log entries from DataDog that match the provided tripId, not just the most recent one.
- **FR-002**: System MUST combine waypoints from all fetched log fragments into a single unified route.
- **FR-003**: System MUST order waypoints chronologically across all log fragments based on their timestamps.
- **FR-004**: System MUST remove duplicate waypoints that may appear in overlapping log fragments.
- **FR-005**: System MUST continue to work correctly for trips with a single log entry (backward compatibility).
- **FR-006**: System MUST display progress feedback when downloading multiple log fragments.
- **FR-007**: System MUST log the number of log fragments found for each tripId.
- **FR-008**: System MUST handle partial failures gracefully, warning the user if some fragments failed but proceeding with available data.
- **FR-009**: System MUST indicate in the output if the visualized route is incomplete due to failed fragment downloads.
- **FR-010**: System MUST retain each log fragment as a separate data structure, allowing individual fragments to be inspected or recreated independently from the combined visualization.
- **FR-011**: System MUST limit processing to a maximum of 50 log fragments per tripId and warn the user if additional fragments exist beyond this limit.
- **FR-012**: System MUST visually distinguish gaps between log fragments (where data is missing) by rendering a dashed line connecting the end of one fragment to the start of the next.
- **FR-013**: System MUST display detailed fragment metadata (timestamps, waypoint counts per fragment) when verbose mode is enabled.

### Key Entities

- **Log Fragment**: A single log entry from DataDog representing a portion of a trip's route. Contains: tripId, timestamp, list of waypoints, session identifier. Each fragment is retained as a separate data model for individual inspection.
- **Unified Route**: A view combining chronologically-ordered waypoints from all log fragments for visualization purposes. Does not replace the underlying fragment data.
- **Trip Session**: A continuous period of app activity. A trip may span multiple sessions if the app crashed/restarted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Trips with multiple log fragments display all waypoints from all fragments in the generated map.
- **SC-002**: Single-log trips continue to visualize correctly with no change in output quality.
- **SC-003**: Users can identify how many log fragments were processed for their tripId from the output.
- **SC-004**: Route visualization completes successfully even if up to 50% of log fragments fail to download.
- **SC-005**: No duplicate waypoints appear in the final route visualization.

## Clarifications

### Session 2025-12-07

- Q: Should log fragments be merged into a single data structure or retained separately? → A: Retain each log as a separate data model; combine only for final map visualization. Individual fragments must remain inspectable.
- Q: How should the system behave when a trip has an unusually large number of log fragments? → A: Cap at 50 fragments with warning if more exist.
- Q: When log fragments have time gaps, how should these gaps appear on the map? → A: Connect with dashed line indicating missing data.
- Q: Should the system output a summary of fragment metadata after processing? → A: Show fragment summary only in verbose mode.

## Assumptions

- Log fragments for the same tripId share the same tripId value in DataDog.
- Each waypoint has a timestamp that allows chronological ordering.
- Waypoint duplicates can be identified by matching coordinates and timestamps.
- The DataDog API supports querying for all logs matching a tripId (not just the most recent).
- The existing DataDog query structure returns logs with timestamp information that can be used for ordering.
