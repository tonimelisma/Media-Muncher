# Media Muncher

MacOS app to automatically import photos and videos from inserted SD cards, USB connected cameras or other storage.

## Todo

### MVP
* Enumerate media files
* Copy them to the destination folder
* Idempotent, don't overwrite
* Remove originals
* Progress bar for import
* Settings
  * Configure metadata-based export directories
  * Configure metadata-based export filenames

### Roadmap
* Logging
* Checksum verification before deletion
* Multi-threading
* Thumbnails
* Show list of detected media in each volume
* Show which media are already imported
* Auto-launch via Launch Agents
* Settings
  * Toggle auto-launch (none, manual GUI, automatic GUI)
  * Configure which volumes to import automatically (all, known, none)
  * Configure import file types (pics, videos, processed vs raw)
  * Eject after importing
