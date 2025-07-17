# Media Muncher – Product Requirements Document (PRD)

## 1. Vision
Media Muncher is a lightweight macOS utility that automatically imports photographs, videos and audio recordings from any removable storage (SD-cards, USB disks, connected cameras) into a user-defined library structure on the Mac. It is a single-purpose tool that does one thing well. It should be as seamless as Apple Photos import, but work with any folder hierarchy, respect professional workflows, guarantee against data-loss, and remain scriptable/automatable for power users.

## 2. Goals
1. Zero-click ingest of media as soon as a card is inserted while still allowing manual control.
2. Never overwrite or delete user data without verifying the data's been successfully imported.
3. Keep a clear audit trail so a professional can prove where every file ended up.
4. Remain fast (imports keep up with UHS-II card readers) and energy-efficient.
5. Blend into the macOS experience (proper sandbox entitlements, system notifications, dark-mode, etc.).

## 3. Non-Goals
* Full-blown Digital Asset Management (tagging, rating, editing).
* Cloud synchronisation.
* Windows or Linux support (at least for the first major release).

## 4. Target Users
* Photographers & videographers who ingest cards daily.
* Hobbyists who want a quick "copy to Pictures & delete originals" workflow.
* IT staff automating media off-loading kiosks.

## 5. Non-Functional Requirements
* Import throughput ≥ 200 MB/s (limited by storage hardware).
* UI remains responsive while scanning/copying (async, batching).
* Compatible with macOS 13+ (Swift 5.9, SwiftUI).
* Minimal permissions – App Sandbox with Removable-Drives & user-selected folders.
* Unit-test coverage ≥ 70 % on core logic.

## 6. Epics & User Stories
Statuses use: **Finished**, **Started**, **Not Started**, **Bug**.

### EPIC 1 – Device Management  
| ID | User Story | Status |
|----|------------|--------|
| DM-1 | As a user, I see a sidebar list of all mounted removable volumes. | **Finished** |
| DM-2 | As a user, I can eject a selected volume safely from within the app. | **Finished** |
| DM-3 | As a power user, the app should ignore non-removable internal drives. | **Finished** |

### EPIC 2 – Media Discovery  
| ID | User Story | Status |
|----|------------|--------|
| MD-1 | When I select or insert a volume the app scans it for media files. | **Finished** |
| MD-2 | The scan shows live progress and can be cancelled. | **Finished** |
| MD-3 | Each file displayed includes a thumbnail. | **Finished** |
| MD-4 | Media that pre-exists in the destination folder are visually marked (defined by file metadata). | **Finished** |
| MD-5 | While the scan is in progress, the thumbnail list updates in real time (although not with jank). | **Finished** |
| MD-6 | The scan intelligently hides sidecar files (e.g., `.THM`, `.XMP`) from the main view, but tracks them internally so they can be managed with their parent media file. | **Finished** |

### EPIC 3 – Import Engine  
| ID | User Story | Status |
|----|------------|--------|
| IE-1 | I press **Import** and files copy to my destination folder. | **Finished** |
| IE-2 | As a user, I can enable a setting to rename destination filenames based on their capture date (e.g., `20250101_120000.jpg`). | **Finished** |
| IE-7 | As a user, I can enable a setting to organize destination files into date-based subfolders (e.g., `2025/01/`). | **Finished** |
| IE-3 | If a file with the same content (based on metadata) already exists at the destination, the app will skip copying it and mark it as pre-existing. | **Finished** |
| IE-4 | If a destination file with the same name but different content exists, the newly imported file will be renamed by appending a numerical suffix (e.g., `IMG_0001_1.JPG`) to prevent overwriting data. | **Finished** |
| IE-5 | As a user, I can enable a setting to delete original files from the source media after they are successfully copied. This also applies to source duplicates of files that already exist in the destination. | **Finished** |
| IE-6 | After import I can eject the volume automatically (setting choosable by user). | **Finished** |
| IE-9 | After successful copy, associated sidecar files (e.g., `.THM` thumbnails for videos) are also deleted from the source. | **Finished** |
| IE-10 | If destination file paths for two source files overlap, the app ensures unique filenames by appending numerical suffixes. | **Finished** |
| IE-11 | I want copied files to use the most accurate timestamp available, trying media metadata (e.g., EXIF capture date) first and falling back to the filesystem's modification time only if no media timestamp exists, so that my library is sorted by when a photo was actually taken. | **Finished** |
| IE-12 | As a user, if the same file exists in multiple folders on my source media, I want the application to import it only once to avoid creating redundant copies in my destination library. | **Finished** |
| IE-13 | As a user, if an import is interrupted or fails mid-way, I want to know exactly which files succeeded and which failed, so no data is silently lost. | **Finished** |

### EPIC 4 – Settings & Preferences  
| ID | User Story | Status |
|----|------------|--------|
| ST-1 | I can choose a destination folder from presets or custom path. | **Finished** |
| ST-2 | I can toggle "Delete originals after import". If enabled, this will delete source files that were successfully copied *and* source files that were skipped because they already exist at the destination. | **Finished** |
| ST-3 | I can enable or disable file/directory renaming based on pre-defined templates. | **Finished** |
| ST-4 | I can whitelist volumes for auto-import. | **Not Started** |
| ST-5 | I can choose which media types to import (photo/video/audio/raw). These categories will be backed by a documented list of file extensions so I know exactly what will be imported. | **Finished** |

The specific file extensions for each category in **ST-5** are:
| Category | File Extensions |
|---|---|
| **Photo** | `.jpg`, `.jpeg`, `.jpe`, `.jif`, `.jfif`, `.jfi`, `.jp2`, `.j2k`, `.jpf`, `.jpm`, `.jpg2`, `.j2c`, `.jpc`, `.jpx`, `.mj2`, `.jxl`, `.png`, `.gif`, `.bmp`, `.tiff`, `.tif`, `.psd`, `.eps`, `.svg`, `.ico`, `.webp`, `.heif`, `.heifs`, `heic`, `.heics`, `.avci`, `.avcs`, `.hif` |
| **Video** | `.mp4`, `.avi`, `.mov`, `.wmv`, `.flv`, `.mkv`, `.webm`, `.ogv`, `.m4v`, `.3gp`, `.3g2`, `.asf`, `.vob`, `.mts`, `.m2ts`, `.braw`, `.r3d`, `.ari` |
| **Audio** | `.mp3`, `.wav`, `.aac` |
| **RAW** | `.arw`, `.cr2`, `.cr3`, `.crw`, `.dng`, `.erf`, `.kdc`, `.mrw`, `.nef`, `.orf`, `.pef`, `.raf`, `.raw`, `.rw2`, `.sr2`, `.srf`, `.x3f` |

### EPIC 5 – User Interface Polish  
| ID | User Story | Status |
|----|------------|--------|
| UI-1 | The grid view adapts to window width. | **Finished** |
| UI-2 | Each media type has a specific icon before thumbnail loads. | **Finished** |
| UI-3 | Import progress bar and time estimate are shown. | **Finished** |
| UI-4 | Errors appear inline with helpful messages. | **Finished** |
| UI-5 | Full dark/light-mode compliance. | **Finished** |

### EPIC 6 – Security & Permissions  
| ID | User Story | Status |
|----|------------|--------|
| SC-1 | The app requests removable-drive entitlement. | **Finished** |
| SC-2 | The app stores destination folder as security-scoped bookmark. | **Finished** |

### EPIC 7 – Automation & Launch Agents
| ID | User Story | Status |
|----|------------|--------|
| AU-1 | App can launch automatically when a new volume is detected. | **Not Started** |
| AU-2 | When the app is automatically launched on a detected volume, the user can choose whether to always automatically launch and automatically import, automatically launch but not import, or never launch for that specific volume. | **Not Started** |
| AU-3 | User can set setting on whether app launches automatically on inserted volumes or not. | **Not Started** |

### EPIC 8 – Logging & Telemetry  
| ID | User Story | Status |
|----|------------|--------|
| LG-1 | Each import action is logged to rotating file in `~/Library/Logs`. | **Finished** |
| LG-2 | Developer-mode console shows verbose debug info. | **Finished** |

### EPIC 9 – Testing & Quality  
| ID | User Story | Status |
|----|------------|--------|
| TQ-1 | Core logic has automated tests with ≥70 % coverage. | **Finished** |
| TQ-2 | Critical UI flows have UI tests. | **Started** |

### EPIC 10 – Performance & Scalability  
| ID | User Story | Status |
|----|------------|--------|
| PF-1 | Enumeration runs on background threads and never blocks UI. | **Finished** |

### 2025-06-27 – Recent Implementation Notes
- Added comprehensive **unit-test suites** for `DestinationPathBuilder`, `FileProcessorService`, `ImportService`, and collision edge-cases. These raised overall core-logic coverage to ~65 % (on track for **TQ-1**).
- Fixed time-zone bug in EXIF date parsing (forced UTC) – previously caused incorrect filenames in some locales.
- Identified and documented four regressions (see `BUGS.md`) and marked their corresponding user stories as **Bug**.

### 2025-06-26 – Previous Notes
- Repaired a broken build state by simplifying service architecture back to a clean, actor-based model and removing failed dependency injection code.
- Replaced fragile, mock-based unit tests with a robust integration test suite that validates the entire import pipeline against the real file system.
- Confirmed all core import logic (renaming, organization, deduplication, deletion) is working correctly and covered by automated tests.

### 2025-06-28 – Read-Only Volume & Collision Fixes
- Implemented read-only volume support; originals remain and user is notified via banner.
- Resolved collision/pre-existing detection bugs; corresponding user stories marked Finished.

### 2025-06-28 – Coverage Bump
- Added AppState workflow tests (scan cancel, auto-eject) bringing line-coverage to >85 %.
- Deterministic file enumeration ensures filename-collision behaviour predictable.

### 2025-06-29 – Duplicate Detection & Mtime Preservation
- Implemented duplicate-in-source detection; only one copy of identical files is imported.
- Destination files now inherit **modification & creation timestamps** from the source.
- Side-car thumbnails (.THM) are automatically removed when their parent video is deleted post-import.
- Added three unit-test suites covering the above; overall coverage surpasses 90 %.

### 2025-07-16 – Actor-based Logging Refactor
* Replaced GCD queue in `LogManager` with **actor-isolated implementation** for full Swift Concurrency safety.
* Log file name now includes the PID for guaranteed uniqueness per process: `media-muncher-YYYY-MM-DD_HH-mm-ss-<pid>.log`.
* On initialization the logger automatically deletes log files older than **30 days**, keeping the log directory bounded without rotation logic.
* All services receive the logger via `Logging` protocol with a default parameter (`logManager: Logging = LogManager()`), eliminating the old singleton.
* Unit-tests updated: each test host process gets its own log file; concurrency tests now await the logger actor for deterministic results.

### 2025-07-14 – Recalculation Flow Re-architecture
- **Internal reliability improvement**: Re-architected destination change recalculation system using Command Pattern with explicit state machine
- Fixed unpredictable behavior when users rapidly changed destination folders in Settings
- Removed security-scoped bookmark complexity (app no longer sandboxed)
- Enhanced test reliability by replacing polling patterns with deterministic expectations
- All user-facing functionality remains unchanged; improvements are internal architecture and reliability

### 2025-01-15 – Custom JSON Logging System Implementation
- **EPIC 8 completed**: Replaced Apple's Unified Logging with custom JSON-based LogManager system
- Implemented persistent logging to `~/Library/Logs/Media Muncher/` with a new log file created for each application session.
- Added structured metadata logging for all services with category-based organization
- Created comprehensive test suite for LogManager with 100% coverage
- Improved debugging workflow with `jq`-based filtering and real-time log following
- All logging infrastructure now supports structured querying and long-term log analysis

---
**Legend**:  
*Finished* – Implemented and shipped in `main`.  
*Started* – Some code exists but not complete.  
*Not Started* – No implementation yet.  
*Bug* – Feature exists but currently fails automated tests or exhibits incorrect runtime behaviour.