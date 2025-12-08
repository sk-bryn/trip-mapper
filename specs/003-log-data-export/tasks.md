# Tasks: Log Data Export

**Input**: Design documents from `/specs/003-log-data-export/`
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

- [x] T001 [P] Create OrderSummary model in TripVisualizer/Sources/TripVisualizer/Models/OrderSummary.swift
- [x] T002 [P] Create ExportSummary model in TripVisualizer/Sources/TripVisualizer/Models/ExportSummary.swift
- [x] T003 [P] Create RouteSegmentExport model in TripVisualizer/Sources/TripVisualizer/Models/RouteSegmentExport.swift
- [x] T004 [P] Create TripDataExport model in TripVisualizer/Sources/TripVisualizer/Models/TripDataExport.swift

---

## Phase 2: Foundational (Core Service)

**Purpose**: Core infrastructure that MUST be complete before user stories can be implemented

**Critical**: No user story work can begin until this phase is complete

- [x] T005 Create DataExportGenerator service in TripVisualizer/Sources/TripVisualizer/Services/DataExportGenerator.swift
- [x] T006 Implement generateExport method in DataExportGenerator per contracts/data-export-generator.md
- [x] T007 Implement writeExport method in DataExportGenerator with pretty-printed JSON output
- [x] T008 Implement generateAndWrite convenience method in DataExportGenerator

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 + 2 - Export Raw Log Data with Human-Readable Format (Priority: P1)

**Goal**: Create data export file automatically for every visualization with route segment correlations, orderIds, and waypoint counts in pretty-printed JSON

**Note**: US1 and US2 are combined since they are both P1 priority and share implementation - US1 creates the export, US2 ensures human-readability (JSON formatting)

**Independent Test**: Run visualizer on any tripId and verify a `-data.json` file is created alongside map outputs containing readable log information

### Tests for User Story 1+2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] Create OrderSummaryTests in TripVisualizer/Tests/TripVisualizerTests/Models/OrderSummaryTests.swift
- [x] T010 [P] [US1] Create ExportSummaryTests in TripVisualizer/Tests/TripVisualizerTests/Models/ExportSummaryTests.swift
- [x] T011 [P] [US1] Create RouteSegmentExportTests in TripVisualizer/Tests/TripVisualizerTests/Models/RouteSegmentExportTests.swift
- [x] T012 [P] [US1] Create TripDataExportTests in TripVisualizer/Tests/TripVisualizerTests/Models/TripDataExportTests.swift
- [x] T013 [P] [US1] Create DataExportGeneratorTests in TripVisualizer/Tests/TripVisualizerTests/Services/DataExportGeneratorTests.swift

### Implementation for User Story 1+2

- [x] T014 [US1] Implement RouteSegmentExport.from(index:fragment:) factory method with orderId grouping
- [x] T015 [US1] Implement TripDataExport.from(tripId:logs:route:metadata:) factory method with orderSequence extraction
- [x] T016 [US1] Implement orderSequence extraction logic (unique orderIds in first-occurrence order)
- [x] T017 [US1] Configure JSONEncoder with prettyPrinted, sortedKeys, and iso8601 date strategy in DataExportGenerator
- [x] T018 [US1] Integrate DataExportGenerator into TripVisualizerService.visualize() after map generation
- [x] T019 [US1] Add export file path to visualization output summary
- [x] T020 [US1] Handle export failure gracefully (log warning, don't fail visualization)

**Checkpoint**: User Stories 1+2 complete - export file created automatically with human-readable JSON

---

## Phase 4: User Story 3 - Include DataDog Reference Links (Priority: P2)

**Goal**: Include clickable DataDog URLs in the export file for each route segment

**Independent Test**: Open data export file, find DataDog URL, click it to verify it opens correct log entry

### Tests for User Story 3

- [x] T021 [P] [US3] Add DataDog URL validation tests to RouteSegmentExportTests

### Implementation for User Story 3

- [x] T022 [US3] Verify datadogUrl field populated from LogFragment.logLink in RouteSegmentExport
- [x] T023 [US3] Add test for URL format correctness in export output

**Checkpoint**: All user stories complete - export includes DataDog links

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T024 [P] Update inline documentation with DocC-compatible comments for all new models
- [x] T025 [P] Update inline documentation with DocC-compatible comments for DataExportGenerator service
- [x] T026 Create integration test for data export in TripVisualizer/Tests/TripVisualizerTests/Integration/DataExportIntegrationTests.swift
- [x] T027 Run all tests and verify passing: `swift test`
- [x] T028 Verify quickstart.md testing checklist items pass
- [x] T029 Run build to verify no warnings: `swift build`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-4)**: All depend on Foundational phase completion
  - US1+US2 must complete before US3 (US3 verifies URLs already added)
- **Polish (Phase 5)**: Depends on all user stories being complete

### User Story Dependencies

| User Story | Depends On | Can Run In Parallel With |
|------------|------------|-------------------------|
| US1+US2 (Export + Format) | Phase 2 | - |
| US3 (DataDog Links) | US1+US2 | - |

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
T009 || T010 || T011 || T012 || T013
```

---

## Parallel Example: User Story 1+2 Tests

```bash
# Launch all tests for User Story 1+2 together:
Task: "Create OrderSummaryTests in TripVisualizer/Tests/TripVisualizerTests/Models/OrderSummaryTests.swift"
Task: "Create ExportSummaryTests in TripVisualizer/Tests/TripVisualizerTests/Models/ExportSummaryTests.swift"
Task: "Create RouteSegmentExportTests in TripVisualizer/Tests/TripVisualizerTests/Models/RouteSegmentExportTests.swift"
Task: "Create TripDataExportTests in TripVisualizer/Tests/TripVisualizerTests/Models/TripDataExportTests.swift"
Task: "Create DataExportGeneratorTests in TripVisualizer/Tests/TripVisualizerTests/Services/DataExportGeneratorTests.swift"
```

---

## Implementation Strategy

### MVP First (User Stories 1+2 Only)

1. Complete Phase 1: Setup (new models)
2. Complete Phase 2: Foundational (DataExportGenerator service)
3. Complete Phase 3: User Stories 1+2 (export creation + formatting)
4. **STOP and VALIDATE**: Test export file creation and readability
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Stories 1+2 → Test export creation → Deploy/Demo (MVP!)
3. Add User Story 3 → Test DataDog links → Deploy/Demo
4. Complete Polish → Final release

### Recommended Order for Single Developer

1. Phase 1 (all tasks parallel)
2. Phase 2 (sequential - service depends on models)
3. Phase 3 tests (all parallel)
4. Phase 3 implementation (sequential)
5. Phase 4 (US3 - verify links)
6. Phase 5 (Polish)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution requires TDD: write tests first, verify they fail, then implement
- US1 and US2 are combined because they're both P1 and deeply interrelated (export + format)
- US3 is mostly verification since datadogUrl is populated from existing LogFragment.logLink
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
