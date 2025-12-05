# Tasks: Trip Route Visualizer CLI

**Input**: Design documents from `/specs/001-trip-route-visualizer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per constitution requirement (Test-First Development is NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
```
TripVisualizer/
├── Package.swift
├── Sources/TripVisualizer/
├── Tests/TripVisualizerTests/
└── logs/
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Swift Package Manager setup

- [x] T001 Create TripVisualizer directory structure per plan.md
- [x] T002 Initialize Swift Package with Package.swift including swift-argument-parser dependency
- [x] T003 [P] Create logs/ directory at TripVisualizer/logs/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Phase

- [x] T004 [P] Create test target structure in TripVisualizer/Tests/TripVisualizerTests/
- [x] T005 [P] Write unit tests for Waypoint model validation in Tests/TripVisualizerTests/Models/WaypointTests.swift
- [x] T006 [P] Write unit tests for Trip model validation in Tests/TripVisualizerTests/Models/TripTests.swift
- [x] T007 [P] Write unit tests for Configuration model (including datadogEnv, datadogService fields) in Tests/TripVisualizerTests/Models/ConfigurationTests.swift

### Implementation for Foundational Phase

- [x] T008 [P] Create Waypoint model with latitude, longitude, orderId in Sources/TripVisualizer/Models/Waypoint.swift
- [x] T009 [P] Create Trip model with id, logId, logLink, waypoints, timestamp in Sources/TripVisualizer/Models/Trip.swift
- [x] T010 [P] Create Configuration model with datadogEnv, datadogService, outputFormats, and all fields per data-model.md in Sources/TripVisualizer/Models/Configuration.swift
- [x] T011 [P] Create OutputFormat enum in Sources/TripVisualizer/Models/OutputFormat.swift
- [x] T012 [P] Create LogLevel enum in Sources/TripVisualizer/Models/LogLevel.swift
- [x] T013 [P] Create TripVisualizerError enum with exit codes per contracts/cli-interface.md in Sources/TripVisualizer/Models/Errors.swift
- [x] T014 [P] Implement Environment utility for reading API keys (DD_API_KEY, DD_APP_KEY, GOOGLE_MAPS_API_KEY) from env vars in Sources/TripVisualizer/Utilities/Environment.swift
- [x] T015 [P] Implement Logger utility with file and stderr output in Sources/TripVisualizer/Utilities/Logger.swift
- [x] T016 Implement ConfigurationLoader to load JSON config files in Sources/TripVisualizer/Services/ConfigurationLoader.swift
- [x] T017 Implement file logging to logs/<tripId>-<timestamp>.log (FR-010) in Sources/TripVisualizer/Utilities/Logger.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Visualize Trip Route (Priority: P1) MVP

**Goal**: Accept a trip UUID, fetch logs from DataDog, extract waypoints, generate map visualization

**Independent Test**: Run `tripvisualizer <valid-uuid>` and verify PNG image and HTML file are generated with plotted route

### Tests for User Story 1

- [x] T018 [P] [US1] Write unit tests for DataDogClient (including query construction with env, service, trip_id filters) in Tests/TripVisualizerTests/Services/DataDogClientTests.swift
- [x] T019 [P] [US1] Write unit tests for LogParser coordinate extraction in Tests/TripVisualizerTests/Services/LogParserTests.swift
- [x] T020 [P] [US1] Write unit tests for PolylineEncoder in Tests/TripVisualizerTests/Services/PolylineEncoderTests.swift
- [x] T021 [P] [US1] Write unit tests for MapGenerator in Tests/TripVisualizerTests/Services/MapGeneratorTests.swift
- [x] T022 [P] [US1] Write integration test for end-to-end visualization in Tests/TripVisualizerTests/Integration/VisualizationIntegrationTests.swift

### Implementation for User Story 1

- [x] T023 [US1] Implement DataDog response models (DataDogLogResponse, DataDogLogEntry) in Sources/TripVisualizer/Models/DataDogModels.swift
- [x] T024 [US1] Implement DataDogClient with async/await HTTP requests and query construction (env + @trip_id + service + content filter) per contracts/datadog-api.md in Sources/TripVisualizer/Services/DataDogClient.swift
- [x] T025 [US1] Implement LogParser to extract waypoints from segment_coords in Sources/TripVisualizer/Services/LogParser.swift
- [x] T026 [US1] Implement PolylineEncoder (Google's encoding algorithm) in Sources/TripVisualizer/Services/PolylineEncoder.swift
- [x] T027 [US1] Create map-template.html with Google Maps JavaScript API per contracts/google-maps-api.md in Sources/TripVisualizer/Resources/map-template.html
- [x] T028 [US1] Implement MapGenerator for HTML output in Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T029 [US1] Add Static Maps API URL generation to MapGenerator for PNG output
- [x] T030 [US1] Add PNG download functionality to MapGenerator using URLSession
- [x] T031 [US1] Implement VisualizeCommand with ArgumentParser in Sources/TripVisualizer/Commands/VisualizeCommand.swift
- [x] T032 [US1] Create main.swift entry point with command registration in Sources/TripVisualizer/main.swift
- [x] T033 [US1] Implement TripVisualizer orchestrator connecting all services in Sources/TripVisualizer/Services/TripVisualizer.swift

**Checkpoint**: User Story 1 complete - basic visualization works with `tripvisualizer <uuid>`

---

## Phase 4: User Story 2 - Handle Invalid or Missing Trips (Priority: P2)

**Goal**: Provide clear error messages for invalid UUIDs, missing trips, no route data, and multiple logs

**Independent Test**: Run with invalid UUID, non-existent trip, and verify appropriate error messages and exit codes

### Tests for User Story 2

- [ ] T034 [P] [US2] Write unit tests for UUID validation in Tests/TripVisualizerTests/Services/ValidationTests.swift
- [ ] T035 [P] [US2] Write unit tests for error scenarios in DataDogClient (0 logs, >1 logs) in Tests/TripVisualizerTests/Services/DataDogClientErrorTests.swift
- [ ] T036 [P] [US2] Write unit tests for insufficient waypoints error in Tests/TripVisualizerTests/Services/LogParserErrorTests.swift

### Implementation for User Story 2

- [ ] T037 [US2] Add UUID validation to VisualizeCommand with descriptive error in Sources/TripVisualizer/Commands/VisualizeCommand.swift
- [ ] T038 [US2] Add trip-not-found error handling to DataDogClient (0 logs returned)
- [ ] T039 [US2] Add multiple-logs error handling to DataDogClient (>1 logs returned, FR-016)
- [ ] T040 [US2] Add insufficient-waypoints error handling to LogParser (<2 waypoints)
- [ ] T041 [US2] Add invalid-coordinate handling to LogParser (skip with warning)
- [ ] T042 [US2] Ensure all errors output to stderr with correct exit codes per contracts/cli-interface.md

**Checkpoint**: User Story 2 complete - all error cases handled with clear messages

---

## Phase 5: User Story 3 - View Progress During Processing (Priority: P3)

**Goal**: Display progress indicators for fetch and processing operations taking >2 seconds

**Independent Test**: Run with `--verbose` flag and verify progress output on stderr during DataDog fetch and map generation

### Tests for User Story 3

- [ ] T043 [P] [US3] Write unit tests for ProgressReporter in Tests/TripVisualizerTests/Utilities/ProgressReporterTests.swift

### Implementation for User Story 3

- [ ] T044 [US3] Implement ProgressReporter with TTY detection and ANSI codes in Sources/TripVisualizer/Utilities/ProgressReporter.swift
- [ ] T045 [US3] Add --verbose and --quiet flags to VisualizeCommand in Sources/TripVisualizer/Commands/VisualizeCommand.swift
- [ ] T046 [US3] Integrate ProgressReporter into DataDogClient for fetch progress
- [ ] T047 [US3] Integrate ProgressReporter into MapGenerator for generation progress
- [ ] T048 [US3] Add 2-second threshold check before showing progress (FR-008)

**Checkpoint**: User Story 3 complete - progress indicators shown for long operations

---

## Phase 6: User Story 4 - Configure Output Format (Priority: P3)

**Goal**: Allow users to choose output format (image, html, url, or all) via CLI flag and config file

**Independent Test**: Run with `-f image`, `-f html`, `-f url` and verify only specified outputs are generated

### Tests for User Story 4

- [ ] T049 [P] [US4] Write unit tests for output format selection in Tests/TripVisualizerTests/Commands/VisualizeCommandTests.swift
- [ ] T050 [P] [US4] Write unit tests for config file loading (including datadogEnv, datadogService) in Tests/TripVisualizerTests/Services/ConfigurationLoaderTests.swift

### Implementation for User Story 4

- [ ] T051 [US4] Add --format flag to VisualizeCommand with image/html/url/all options
- [ ] T052 [US4] Add --output flag for output directory selection
- [ ] T053 [US4] Add --config flag for custom config file path
- [ ] T054 [US4] Update TripVisualizer to respect output format selection
- [ ] T055 [US4] Implement config file discovery (~/.tripvisualizer/config.json, ./config.json)
- [ ] T056 [US4] Add URL output mode (print Google Maps URL to stdout)

**Checkpoint**: User Story 4 complete - output format fully configurable

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and final quality improvements

- [ ] T057 [P] Create README.md with installation and usage instructions in TripVisualizer/README.md
- [ ] T058 [P] Add --help output verification matching contracts/cli-interface.md
- [ ] T059 [P] Add --version flag implementation
- [ ] T060 Add log redaction for sensitive data (API keys in error messages)
- [ ] T061 Add retry logic with exponential backoff for network failures (FR-015)
- [ ] T062 [P] Cross-platform testing: verify build on Linux
- [ ] T063 Run quickstart.md validation - execute all documented examples
- [ ] T064 Performance validation: verify <30s for 500 waypoints (SC-001)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 -> P2 -> P3)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Enhances US1 error handling but independently testable
- **User Story 3 (P3)**: Can start after Foundational - Adds to existing commands but independently testable
- **User Story 4 (P3)**: Can start after Foundational - Adds configuration layer but independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Constitution: Test-First)
- Models before services
- Services before commands
- Core implementation before integration

### Parallel Opportunities

**Phase 1 (Setup)**:
- T003 can run in parallel with T001/T002

**Phase 2 (Foundational)**:
- T004-T007 (tests) can run in parallel
- T008-T015 (models/utilities) can run in parallel
- T016-T017 depend on T010 (Configuration model) and T015 (Logger)

**Phase 3 (User Story 1)**:
- T018-T022 (tests) can run in parallel
- T023 before T024 (models before service)
- T024-T026 must be sequential (service dependencies)
- T027-T030 (MapGenerator) after T026

**Phase 4-6**:
- All test tasks within each phase can run in parallel
- Implementation tasks follow dependency order

---

## Parallel Example: Phase 2 Foundational

```bash
# Launch all foundational tests together:
Task: "Write unit tests for Waypoint model in Tests/TripVisualizerTests/Models/WaypointTests.swift"
Task: "Write unit tests for Trip model in Tests/TripVisualizerTests/Models/TripTests.swift"
Task: "Write unit tests for Configuration model in Tests/TripVisualizerTests/Models/ConfigurationTests.swift"

# Launch all model implementations together:
Task: "Create Waypoint model in Sources/TripVisualizer/Models/Waypoint.swift"
Task: "Create Trip model in Sources/TripVisualizer/Models/Trip.swift"
Task: "Create Configuration model in Sources/TripVisualizer/Models/Configuration.swift"
Task: "Create OutputFormat enum in Sources/TripVisualizer/Models/OutputFormat.swift"
Task: "Create LogLevel enum in Sources/TripVisualizer/Models/LogLevel.swift"
Task: "Create TripVisualizerError enum in Sources/TripVisualizer/Models/Errors.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test with real DataDog trip ID
5. Deploy/demo basic visualization capability

### Incremental Delivery

1. Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Basic visualization works (MVP!)
3. Add User Story 2 -> Error handling robust
4. Add User Story 3 -> Progress feedback
5. Add User Story 4 -> Configurable output
6. Polish -> Production ready

### Suggested MVP Scope

**User Story 1 only** - provides core value:
- Accept trip UUID
- Fetch from DataDog with proper query filters (env + @trip_id + service + content)
- Generate PNG and HTML map
- Basic error handling for API failures

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD per constitution)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All API keys via environment variables (Constitution: Security-First)
- DataDog query uses config values: `env:<datadogEnv> @trip_id:<uuid> service:<datadogService> "received request for SaveActualRouteForTrip"`
