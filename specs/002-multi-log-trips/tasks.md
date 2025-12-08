# Tasks: Multi-Log Trip Support

**Input**: Design documents from `/specs/002-multi-log-trips/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are included per Constitution II: Test-First Development (NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md project structure:
- **Source**: `TripVisualizer/Sources/TripVisualizer/`
- **Tests**: `TripVisualizer/Tests/TripVisualizerTests/`

---

## Phase 1: Setup (New Models)

**Purpose**: Create new data models that have no dependencies on existing code changes

- [ ] T001 [P] Create SegmentType enum and RouteSegment model in TripVisualizer/Sources/TripVisualizer/Models/RouteSegment.swift
- [ ] T002 [P] Create LogFragment model in TripVisualizer/Sources/TripVisualizer/Models/LogFragment.swift
- [ ] T003 [P] Create TripMetadata model in TripVisualizer/Sources/TripVisualizer/Models/TripMetadata.swift
- [ ] T004 [P] Create UnifiedRoute model in TripVisualizer/Sources/TripVisualizer/Models/UnifiedRoute.swift

---

## Phase 2: Foundational (Core Service + Model Updates)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**Critical**: No user story work can begin until this phase is complete

- [ ] T005 Extend Waypoint model with optional fragmentId property in TripVisualizer/Sources/TripVisualizer/Models/Waypoint.swift
- [ ] T006 Create FragmentAggregator service in TripVisualizer/Sources/TripVisualizer/Services/FragmentAggregator.swift
- [ ] T007 Add maxFragments and gapThresholdSeconds to Configuration in TripVisualizer/Sources/TripVisualizer/Models/Configuration.swift
- [ ] T008 Update ConfigurationLoader defaults for new config options in TripVisualizer/Sources/TripVisualizer/Services/ConfigurationLoader.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - View Complete Trip Route After App Crash (Priority: P1)

**Goal**: Enable visualization of trips with multiple log fragments, combining all waypoints into a single unified route

**Independent Test**: Provide a tripId with multiple log fragments and verify the output map shows all waypoints from all fragments in chronological order

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T009 [P] [US1] Create LogFragmentTests in TripVisualizer/Tests/TripVisualizerTests/Models/LogFragmentTests.swift
- [ ] T010 [P] [US1] Create RouteSegmentTests in TripVisualizer/Tests/TripVisualizerTests/Models/RouteSegmentTests.swift
- [ ] T011 [P] [US1] Create UnifiedRouteTests in TripVisualizer/Tests/TripVisualizerTests/Models/UnifiedRouteTests.swift
- [ ] T012 [P] [US1] Create FragmentAggregatorTests in TripVisualizer/Tests/TripVisualizerTests/Services/FragmentAggregatorTests.swift

### Implementation for User Story 1

- [ ] T013 [US1] Add fetchAllLogs method to DataDogClient in TripVisualizer/Sources/TripVisualizer/Services/DataDogClient.swift
- [ ] T014 [US1] Update LogParser to return LogFragment in TripVisualizer/Sources/TripVisualizer/Services/LogParser.swift
- [ ] T015 [US1] Implement fragment ordering logic in FragmentAggregator in TripVisualizer/Sources/TripVisualizer/Services/FragmentAggregator.swift
- [ ] T016 [US1] Implement waypoint deduplication logic in FragmentAggregator in TripVisualizer/Sources/TripVisualizer/Services/FragmentAggregator.swift
- [ ] T017 [US1] Implement gap detection logic in FragmentAggregator in TripVisualizer/Sources/TripVisualizer/Services/FragmentAggregator.swift
- [ ] T018 [US1] Add segment-based writeHTML method to MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [ ] T019 [US1] Add dashed line rendering for gap segments in MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [ ] T020 [US1] Update static map generation to use gray color for gaps in MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift
- [ ] T021 [US1] Update TripVisualizerService to use multi-fragment flow in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [ ] T022 [US1] Update Trip model to support fragments and UnifiedRoute in TripVisualizer/Sources/TripVisualizer/Models/Trip.swift
- [ ] T023 [US1] Implement 50-fragment limit with warning in TripVisualizerService in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [ ] T024 [US1] Implement partial failure handling in TripVisualizerService in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift

**Checkpoint**: User Story 1 should be fully functional - trips with multiple logs display complete routes

---

## Phase 4: User Story 2 - Single Log Trip Still Works (Priority: P1)

**Goal**: Ensure backward compatibility so single-log trips continue to work identically

**Independent Test**: Provide a tripId with exactly one log entry and verify output matches pre-change behavior

### Tests for User Story 2

- [ ] T025 [P] [US2] Create backward compatibility tests in TripVisualizer/Tests/TripVisualizerTests/Services/BackwardCompatibilityTests.swift
- [ ] T026 [P] [US2] Create single-fragment aggregation test in TripVisualizer/Tests/TripVisualizerTests/Services/FragmentAggregatorTests.swift

### Implementation for User Story 2

- [ ] T027 [US2] Verify single-log behavior matches current implementation in TripVisualizerService
- [ ] T028 [US2] Ensure no warnings shown for single-log trips in TripVisualizerService
- [ ] T029 [US2] Add backward-compatible writeHTML overload in MapGenerator in TripVisualizer/Sources/TripVisualizer/Services/MapGenerator.swift

**Checkpoint**: Both multi-log (US1) and single-log (US2) trips work correctly

---

## Phase 5: User Story 3 - Progress Feedback for Multi-Log Downloads (Priority: P2)

**Goal**: Display progress feedback when downloading multiple log fragments

**Independent Test**: Trigger visualization of a tripId with multiple logs and observe progress output

### Tests for User Story 3

- [ ] T030 [P] [US3] Create progress indicator tests for multi-fragment display in TripVisualizer/Tests/TripVisualizerTests/Utilities/ProgressIndicatorTests.swift

### Implementation for User Story 3

- [ ] T031 [US3] Add multi-fragment progress messages to ProgressIndicator in TripVisualizer/Sources/TripVisualizer/Utilities/ProgressIndicator.swift
- [ ] T032 [US3] Integrate progress updates into TripVisualizerService fragment loop in TripVisualizer/Sources/TripVisualizer/Services/TripVisualizer.swift
- [ ] T033 [US3] Add verbose mode fragment metadata display (timestamps, waypoint counts) in TripVisualizerService
- [ ] T034 [US3] Display fragment count in final summary output in TripVisualizerService

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T035 [P] Update inline documentation with DocC-compatible comments for all new models
- [ ] T036 [P] Update inline documentation with DocC-compatible comments for all modified services
- [ ] T037 Create integration test for multi-log trip scenario in TripVisualizer/Tests/TripVisualizerTests/Integration/MultiLogTripTests.swift
- [ ] T038 Run all tests and verify passing: `swift test`
- [ ] T039 Verify quickstart.md testing checklist items pass
- [ ] T040 Run build to verify no warnings: `swift build`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 and US2 can proceed in parallel (both P1 priority)
  - US3 can proceed independently after Foundational
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

| User Story | Depends On | Can Run In Parallel With |
|------------|------------|-------------------------|
| US1 (Multi-Log) | Phase 2 | US2, US3 |
| US2 (Single-Log Compat) | Phase 2 | US1, US3 |
| US3 (Progress Feedback) | Phase 2 | US1, US2 |

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- Services before integration
- Core implementation before polish

### Parallel Opportunities

**Phase 1 (all parallel):**
```
T001 || T002 || T003 || T004
```

**Phase 3 Tests (all parallel):**
```
T009 || T010 || T011 || T012
```

**Phase 4 Tests (all parallel):**
```
T025 || T026
```

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Create LogFragmentTests in TripVisualizer/Tests/TripVisualizerTests/Models/LogFragmentTests.swift"
Task: "Create RouteSegmentTests in TripVisualizer/Tests/TripVisualizerTests/Models/RouteSegmentTests.swift"
Task: "Create UnifiedRouteTests in TripVisualizer/Tests/TripVisualizerTests/Models/UnifiedRouteTests.swift"
Task: "Create FragmentAggregatorTests in TripVisualizer/Tests/TripVisualizerTests/Services/FragmentAggregatorTests.swift"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (new models)
2. Complete Phase 2: Foundational (core service)
3. Complete Phase 3: User Story 1 (multi-log support)
4. Complete Phase 4: User Story 2 (backward compatibility)
5. **STOP and VALIDATE**: Test both multi-log and single-log trips
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test multi-log trips → Validate
3. Add User Story 2 → Test single-log trips → Deploy/Demo (MVP!)
4. Add User Story 3 → Test progress feedback → Deploy/Demo
5. Complete Polish → Final release

### Recommended Order for Single Developer

Given US1 and US2 are both P1 priority:
1. Phase 1 (all tasks parallel)
2. Phase 2 (sequential)
3. Phase 3 (US1 - core multi-log feature)
4. Phase 4 (US2 - verify backward compat)
5. Phase 5 (US3 - progress feedback)
6. Phase 6 (Polish)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution requires TDD: write tests first, verify they fail, then implement
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
