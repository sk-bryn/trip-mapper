# Tasks: Order & Location Enrichment

**Input**: Design documents from `/specs/004-order-location-enrichment/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Per constitution requirement (II. Test-First Development), unit tests are included for all new code.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `TripVisualizer/Sources/TripVisualizer/` for source, `TripVisualizer/Tests/TripVisualizerTests/` for tests
- Per plan.md project structure

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and shared model/configuration setup

- [x] T001 Create MarkerStyle model with defaults in TripVisualizer/Sources/TripVisualizer/Models/MarkerStyle.swift
- [x] T002 Add marker style configuration fields to TripVisualizer/Sources/TripVisualizer/Models/Configuration.swift
- [x] T003 Create EnrichmentStatus model in TripVisualizer/Sources/TripVisualizer/Models/EnrichmentStatus.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core enrichment infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Create EnrichmentResult model with empty factory in TripVisualizer/Sources/TripVisualizer/Models/EnrichmentResult.swift
- [x] T005 [P] Add enrichment query builder methods to Configuration in TripVisualizer/Sources/TripVisualizer/Models/Configuration.swift
- [x] T006 Add fetchEnrichmentLogs method to DataDogClient in TripVisualizer/Sources/TripVisualizer/Services/DataDogClient.swift
- [x] T007 Create EnrichmentService skeleton with EnrichmentFetching protocol in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T008 [P] Create EnrichmentResultTests in TripVisualizer/Tests/TripVisualizerTests/EnrichmentResultTests.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - View Delivery Dropoff Addresses on Map (Priority: P1) 🎯 MVP

**Goal**: Display delivery destination markers on the map for each order with address data

**Independent Test**: Run visualizer on a tripId with orderIds; verify delivery addresses appear as distinct purple markers on map

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] Create DeliveryDestinationTests with validation tests in TripVisualizer/Tests/TripVisualizerTests/DeliveryDestinationTests.swift
- [x] T010 [P] [US1] Add fetchDeliveryOrders test cases to EnrichmentServiceTests in TripVisualizer/Tests/TripVisualizerTests/EnrichmentServiceTests.swift
- [x] T011 [P] [US1] Add delivery marker generation tests to MapGeneratorEnrichmentTests in TripVisualizer/Tests/TripVisualizerTests/MapGeneratorEnrichmentTests.swift

### Implementation for User Story 1

- [x] T012 [P] [US1] Create DeliveryDestination model with coordinate validation in TripVisualizer/Sources/TripVisualizer/Models/DeliveryDestination.swift
- [x] T013 [US1] Implement fetchDeliveryOrderLogs query in DataDogClient in TripVisualizer/Sources/TripVisualizer/Services/DataDogClient.swift
- [x] T014 [US1] Implement parseDeliveryDestination from log response in EnrichmentService in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T015 [US1] Implement fetchDeliveryDestinations method in EnrichmentService in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T016 [US1] Add generateDeliveryDestinationMarkersJS method to MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T017 [US1] Update generateHTML to include delivery destination markers in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T018 [US1] Update generateStaticMapsURL to include delivery destination markers in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T019 [US1] Update legend HTML to include delivery destination marker entry in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T020 [US1] Add graceful degradation for missing order data with warnings in EnrichmentService in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift

**Checkpoint**: User Story 1 complete - delivery addresses show on map with distinct purple markers

---

## Phase 4: User Story 2 - View Restaurant Origin Location (Priority: P1)

**Goal**: Display restaurant location marker on the map with name and address

**Independent Test**: Run visualizer on a tripId; verify restaurant name/address appears as distinct blue marker

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T021 [P] [US2] Create RestaurantLocationTests with validation tests in TripVisualizer/Tests/TripVisualizerTests/RestaurantLocationTests.swift
- [x] T022 [P] [US2] Add fetchRestaurantLocation test cases to EnrichmentServiceTests in TripVisualizer/Tests/TripVisualizerTests/EnrichmentServiceTests.swift
- [x] T023 [P] [US2] Add restaurant marker generation tests to MapGeneratorEnrichmentTests in TripVisualizer/Tests/TripVisualizerTests/MapGeneratorEnrichmentTests.swift

### Implementation for User Story 2

- [x] T024 [P] [US2] Create RestaurantLocation model with formattedAddress computed property in TripVisualizer/Sources/TripVisualizer/Models/RestaurantLocation.swift
- [x] T025 [US2] Implement fetchLocationDetailsLogs query in DataDogClient in TripVisualizer/Sources/TripVisualizer/Services/DataDogClient.swift
- [x] T026 [US2] Implement parseRestaurantLocation from log response in EnrichmentService in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T027 [US2] Implement fetchRestaurantLocation method in EnrichmentService in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T028 [US2] Add generateRestaurantMarkerJS method to MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T029 [US2] Update generateHTML to include restaurant origin marker in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T030 [US2] Update generateStaticMapsURL to include restaurant origin marker in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T031 [US2] Update legend HTML to include restaurant marker entry in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T032 [US2] Add graceful degradation for missing location data with warnings in EnrichmentService in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift

**Checkpoint**: User Story 2 complete - restaurant location shows on map with distinct blue marker

---

## Phase 5: User Story 3 - Include Enriched Data in Export File (Priority: P2)

**Goal**: Include restaurant and delivery address data in map-data.json export with status indicators

**Independent Test**: Generate visualization; verify map-data.json contains restaurantLocation, deliveryDestinations, and enrichmentStatus sections

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T033 [P] [US3] Add TripDataExport enrichment field tests in TripVisualizer/Tests/TripVisualizerTests/TripDataExportTests.swift
- [x] T034 [P] [US3] Add DataExportGenerator enrichment integration tests in TripVisualizer/Tests/TripVisualizerTests/DataExportGeneratorTests.swift

### Implementation for User Story 3

- [x] T035 [US3] Add enrichment fields to TripDataExport model in TripVisualizer/Sources/TripVisualizer/Models/TripDataExport.swift
- [x] T036 [US3] Update TripDataExport.from factory to accept EnrichmentResult in TripVisualizer/Sources/TripVisualizer/Models/TripDataExport.swift
- [x] T037 [US3] Update DataExportGenerator to include enrichment data in export in TripVisualizer/Sources/TripVisualizer/Services/DataExportGenerator.swift
- [x] T038 [US3] Ensure enrichmentStatus is always present in export (even when empty) in TripVisualizer/Sources/TripVisualizer/Services/DataExportGenerator.swift

**Checkpoint**: User Story 3 complete - map-data.json contains all enrichment data with status indicators

---

## Phase 6: Integration & Orchestration

**Purpose**: Wire enrichment into the main visualization flow

- [x] T039 Implement fetchEnrichmentData orchestration method in EnrichmentService (parallel fetching) in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T040 Extract orderIds from route waypoints for enrichment lookup in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [x] T041 Extract location_number from route log attributes (check @location_number field) or first waypoint metadata in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [x] T042 Integrate EnrichmentService call into TripVisualizer visualization flow in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [x] T043 Pass EnrichmentResult to MapGenerator for marker rendering in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [x] T044 Pass EnrichmentResult to DataExportGenerator for export in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [x] T045 Add integration test for full visualization with enrichment in TripVisualizer/Tests/TripVisualizerTests/TripVisualizerIntegrationTests.swift

**Checkpoint**: Full integration complete - enrichment flows through entire visualization pipeline

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T046 [P] Add warning-level logging for all enrichment failures (FR-010: log when orderId or location_number lookup fails) in TripVisualizer/Sources/TripVisualizer/Services/EnrichmentService.swift
- [x] T047 [P] Verify graceful degradation: visualization completes when enrichment fails in TripVisualizer/Tests/TripVisualizerTests/GracefulDegradationTests.swift
- [x] T048 [P] Add info window click handlers for marker details in MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [x] T049 Run all tests and verify passing: swift test (440 tests pass)
- [ ] T050 Run quickstart.md validation with real tripId (requires DataDog credentials)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2) completion - Can run parallel to US1
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) completion - Can run parallel to US1/US2
- **Integration (Phase 6)**: Depends on US1, US2, US3 completion
- **Polish (Phase 7)**: Depends on Integration (Phase 6) completion

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Independent of other stories
- **User Story 2 (P1)**: Can start after Foundational - Independent of other stories
- **User Story 3 (P2)**: Can start after Foundational - Independent of other stories
- **Note**: US1 and US2 share MapGenerator modifications but touch different methods

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- DataDog query methods before parsing methods
- Parsing before orchestration
- MapGenerator updates after service implementation

### Parallel Opportunities

**Phase 1**: T001, T002, T003 are sequential (Configuration depends on MarkerStyle)

**Phase 2**:
- T004 and T005 can run in parallel
- T008 can run in parallel with T006, T007

**Phase 3 (US1)**:
- T009, T010, T011 can run in parallel (all tests)
- T012 can run in parallel with tests

**Phase 4 (US2)**:
- T021, T022, T023 can run in parallel (all tests)
- T024 can run in parallel with tests

**Phase 5 (US3)**:
- T033, T034 can run in parallel (all tests)

**Cross-Story Parallelism**:
- After Phase 2 completes, US1, US2, US3 can proceed in parallel if team capacity allows

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Create DeliveryDestinationTests in TripVisualizer/Tests/TripVisualizerTests/DeliveryDestinationTests.swift"
Task: "Add fetchDeliveryOrders test cases to EnrichmentServiceTests in TripVisualizer/Tests/TripVisualizerTests/EnrichmentServiceTests.swift"
Task: "Add delivery marker generation tests to MapGeneratorEnrichmentTests in TripVisualizer/Tests/TripVisualizerTests/MapGeneratorEnrichmentTests.swift"

# Once tests written, model can be created in parallel:
Task: "Create DeliveryDestination model in TripVisualizer/Sources/TripVisualizer/Models/DeliveryDestination.swift"
```

## Parallel Example: Cross-Story (after Foundational)

```bash
# After Phase 2 completes, these can run in parallel with different developers:
# Developer A: User Story 1 (Delivery Addresses)
# Developer B: User Story 2 (Restaurant Location)
# Developer C: User Story 3 (Export Enrichment)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Delivery Addresses)
4. **STOP and VALIDATE**: Test delivery addresses appear on map
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Delivery addresses on map → Demo (MVP!)
3. Add User Story 2 → Restaurant location on map → Demo
4. Add User Story 3 → Full export data → Demo
5. Complete Integration → Full pipeline working
6. Each story adds value without breaking previous stories

### Recommended Order (Single Developer)

1. Phase 1: Setup (T001-T003)
2. Phase 2: Foundational (T004-T008)
3. Phase 3: User Story 1 (T009-T020) - delivery addresses
4. Phase 4: User Story 2 (T021-T032) - restaurant location
5. Phase 5: User Story 3 (T033-T038) - export enrichment
6. Phase 6: Integration (T039-T045)
7. Phase 7: Polish (T046-T050)

---

## Summary

| Phase | Tasks | User Story | Parallel Opportunities |
|-------|-------|------------|------------------------|
| Setup | 3 | - | Sequential |
| Foundational | 5 | - | T004∥T005, T008∥others |
| US1 | 12 | Delivery Addresses | Tests∥Model, MapGenerator after Service |
| US2 | 12 | Restaurant Location | Tests∥Model, MapGenerator after Service |
| US3 | 6 | Export Enrichment | Tests parallel |
| Integration | 7 | - | Sequential (dependencies) |
| Polish | 5 | - | T046∥T047∥T048 |
| **Total** | **50** | | |

**Tasks per User Story**:
- US1 (Delivery Addresses): 12 tasks
- US2 (Restaurant Location): 12 tasks
- US3 (Export Enrichment): 6 tasks

**Independent Test Criteria**:
- US1: Delivery addresses appear as purple markers on map
- US2: Restaurant location appears as blue marker on map
- US3: map-data.json contains enrichmentStatus and enrichment data

**MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Story 1) = 20 tasks

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Constitution requires TDD - all tests must be written first

