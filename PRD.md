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
| MD-6 | The app skips thumbnails in the discovery part. | **Bug** |

### EPIC 3 – Import Engine  
| ID | User Story | Status |
|----|------------|--------|
| IE-1 | I press **Import** and files copy to my destination folder. | **Finished** |
| IE-2 | If user sets a setting, destination filenames will be renamed follow a hard-coded template (e.g., `YYYY-MM-DD.jpg`). Extensions will also follow a template, e.g. JPEG, JPG and jpeg will all be mapped to .jpg. | **Finished** |
| IE-7 | If user sets a setting, destination folder names follow a hard-coded template (e.g., `YYYY/MM/DD/…`). | **Finished** |
| IE-3 | If a dest-file with same metadata exists, skip copy and mark as existing. | **Bug** |
| IE-4 | If a destination file with the same name but different metadata exists, the newly imported file will be renamed by appending a numerical suffix (e.g., IMG_0001_1.JPG) to prevent overwriting data. | **Bug** |
| IE-5 | After successful copy, originals are deleted (setting choosable by user). | **Finished** |
| IE-6 | After import I can eject the volume automatically (setting choosable by user). | **Finished** |
| IE-9 | After successful copy, thumbnails are deleted. | **Finished** |
| IE-10 | If destination file paths for two source files overlap, ensure unique filenames. | **Bug** |
| IE-11 | I want copied files to use the most accurate timestamp available, trying media metadata (e.g., EXIF capture date) first and falling back to the filesystem's modification time only if no media timestamp exists, so that my library is sorted by when a photo was actually taken. | **Finished** |
| IE-12 | As a user, if the same file exists in multiple folders on my source media, I want the application to import it only once to avoid creating redundant copies in my destination library. | **Finished** |
| IE-13 | As a user, if an import is interrupted or fails mid-way, I want to know exactly which files succeeded and which failed, so no data is silently lost. | **Finished** |

### EPIC 4 – Settings & Preferences  
| ID | User Story | Status |
|----|------------|--------|
| ST-1 | I can choose a destination folder from presets or custom path. | **Finished** |
| ST-2 | I can toggle "Delete originals after import". It will delete both files imported now or earlier, as deemed based on metadata.| **Finished** |
| ST-3 | I can enable or disable file/directory renaming based on pre-defined templates. | **Finished** |
| ST-4 | I can whitelist volumes for auto-import. | **Not Started** |
| ST-5 | I can choose which media types to import (photo/video/audio/raw). These categories will be backed by a documented list of file extensions (e.g., "raw" includes .ARW, .NEF, .CR3, etc.) so I know exactly what will be imported. | **Finished** |

The specific file extensions for each category in **ST-5** are:
| Category | File Extensions |
|---|---|
| **Photo** | `.jpg`, `.jpeg`, `.heic`, `.heif`, `.png`, `.gif`, `.tiff`, `.tif`, `.bmp` |
| **Video** | `.mov`, `.mp4`, `.m4v`, `.avi`, `.mts`, `.m2ts`, `.mpg`, `.mpeg` |
| **Audio** | `.mp3`, `.m4a`, `.aac`, `.wav`, `.aiff`, `.aif` |
| **RAW** | `.cr2`, `.cr3`, `.nef`, `.arw`, `.dng`, `.orf`, `.raf`, `.gpr`, `.rw2` |

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
| LG-1 | Each import action is logged to rotating file in `~/Library/Logs`. | **Not Started** |
| LG-2 | Developer-mode console shows verbose debug info. | **Started** (print statements) |

### EPIC 9 – Testing & Quality  
| ID | User Story | Status |
|----|------------|--------|
| TQ-1 | Core logic has automated tests with ≥70 % coverage. | **Started** |
| TQ-2 | Critical UI flows have UI tests. | **Started** |

### EPIC 10 – Performance & Scalability  
| ID | User Story | Status |
|----|------------|--------|
| PF-1 | Enumeration runs on background threads and never blocks UI. | **Finished** |
| PF-2 | Copy operation streams data with back-pressure. | **Not Started** |
| PF-3 | Large volumes (>1 M files) are handled with constant memory use. | **Not Started** |

### 2025-06-27 – Recent Implementation Notes
- Added comprehensive **unit-test suites** for `DestinationPathBuilder`, `FileProcessorService`, `ImportService`, and collision edge-cases. These raised overall core-logic coverage to ~65 % (on track for **TQ-1**).
- Fixed time-zone bug in EXIF date parsing (forced UTC) – previously caused incorrect filenames in some locales.
- Identified and documented four regressions (see `BUGS.md`) and marked their corresponding user stories as **Bug**.

### 2025-06-26 – Previous Notes
- Repaired a broken build state by simplifying service architecture back to a clean, actor-based model and removing failed dependency injection code.
- Replaced fragile, mock-based unit tests with a robust integration test suite that validates the entire import pipeline against the real file system.
- Confirmed all core import logic (renaming, organization, deduplication, deletion) is working correctly and covered by automated tests.

---
**Legend**:  
*Finished* – Implemented and shipped in `main`.  
*Started* – Some code exists but not complete.  
*Not Started* – No implementation yet.  
*Bug* – Feature exists but currently fails automated tests or exhibits incorrect runtime behaviour.