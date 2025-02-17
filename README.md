# Media Muncher

MacOS app to automatically import photos and videos from inserted SD cards, USB connected cameras or other storage.

## Todo
* Security bookmarks
* Enumeration
* Import, progress bar and cancel button

* Copy them to the destination folder
* Idempotent, don't overwrite
* Rename destination if duplicate filename with different contents exist
* Remove originals

### Roadmap
* Logging
* MTP/PTP devices
* Checksum verification before deletion
* Multi-threading
* Thumbnails
* Show list of detected media in each volume
* Show which media are already imported
* Auto-launch via Launch Agents
* Settings
  * Configure custom metadata-based export directories
  * Configure custom metadata-based export filenames
  * Toggle auto-launch (none, manual GUI, automatic GUI)
  * Configure which volumes to import automatically (all, known, none)
  * Configure import file types (pics, videos, processed vs raw)
  * Eject after importing

