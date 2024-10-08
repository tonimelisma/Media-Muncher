# Media Muncher

MacOS app to automatically import photos and videos from inserted SD cards, USB connected cameras or other storage.

## Todo

### MVP
* Enumerate media files
* Copy them to the destination folder
* Idempotent, don't overwrite
* Remove originals

### V2
* Progress bar for import
* Logging
* Settings
  * Configure metadata-based export directories
  * Configure metadata-based export filenames

### V4
* Show list of detected media in each volume
* Show which media are already imported
* Auto-launch via Launch Agents
* Settings
  * Toggle auto-launch (none, manual GUI, automatic GUI)
  * Configure which volumes to import automatically (all, known, none)
  * Configure import file types (pics, videos, processed vs raw)
  * Delete source when imported
  * Eject after importing
