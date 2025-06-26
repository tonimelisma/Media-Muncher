# Media Muncher – Known Bugs (2025-06-27)

| ID | Component | Summary | Tracking Test / Evidence | Status |
|----|-----------|---------|--------------------------|--------|
| **BUG-1** | Import Engine – Collision Handling | Filename collision suffix (e.g., `_1`, `_2`) is not generated, so two files with identical target names may overwrite each other. | `FileProcessorCollisionTests.testCollision_generatesIncrementingSuffix` (currently `XCTSkip`) | Open |
| **BUG-2** | Import Engine – Pre-existing Detection | A file that already exists at the destination is marked `.imported` instead of `.pre_existing`. | `FileProcessorCollisionTests.testPreExisting_sameFileMarkedPreExisting` (skipped) | Open |
| **BUG-3** | Media Discovery | Thumbnail side-car directories (e.g., `THUMBNAILS`, `.thmbnl`) are still enumerated even though they should be ignored. | Comment inside `FileProcessorServiceTests.testFastEnumerate_skipsThumbnailFoldersAndHiddenFiles` | Open |
| **BUG-4** | Integration Pipeline | `ImportServiceIntegrationTests.testImport_withRenameAndOrganize_createsCorrectPath` fails – exact root cause under investigation (likely path-generation edge-case). | Red integration test; see `test_result.xcresult` bundle | Open |

> This file is kept manually in sync with the automated test-suite. Any bug reproduced by a new failing test (or newly skipped test) should be recorded here until fixed. 