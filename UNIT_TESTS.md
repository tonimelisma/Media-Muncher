# UNIT_TESTS_TODO.md

This document tracks the unit tests for the Media Muncher application, indicating which tests have been implemented and which are yet to be implemented.

## AppState

- [ ] Test initialization of AppState
- [ ] Test setting and getting of volumes
- [ ] Test setting and getting of selectedVolumeID
- [ ] Test setting and getting of defaultSavePath
- [ ] Test persistence of defaultSavePath in UserDefaults

## FileEnumerator

- [ ] Test enumerateFiles with valid path
- [ ] Test enumerateFiles with invalid path
- [ ] Test enumerateFiles with different file types (directories, files)
- [ ] Test enumerateFiles with limit parameter

## MediaViewModel

- [ ] Test initialization of MediaViewModel
- [ ] Test loadFilesForVolume with valid volume ID
- [ ] Test loadFilesForVolume with invalid volume ID
- [ ] Test clearFiles method
- [ ] Test importMedia method (success case)
- [ ] Test importMedia method (failure case)

## VolumeService

- [ ] Test loadVolumes method
- [ ] Test ejectVolume method (success case)
- [ ] Test ejectVolume method (failure case)
- [ ] Test accessVolumeAndCreateBookmark method (success case)
- [ ] Test accessVolumeAndCreateBookmark method (failure case)

## VolumeViewModel

- [ ] Test initialization of VolumeViewModel
- [ ] Test loadVolumes method
- [ ] Test ensureVolumeSelection method
- [ ] Test selectVolume method with valid ID
- [ ] Test selectVolume method with invalid ID
- [ ] Test ejectVolume method (success case)
- [ ] Test ejectVolume method (failure case)
- [ ] Test refreshVolumes method

## UI Components (using ViewInspector for SwiftUI testing)

- [ ] Test ContentView layout and navigation
- [ ] Test VolumeView list rendering and selection
- [ ] Test MediaView file item rendering
- [ ] Test FolderSelector functionality
- [ ] Test SettingsView layout and functionality

## How to use this document

1. As you implement each test, change the `[ ]` to `[x]` to mark it as completed.
2. Add new tests to the relevant sections as needed.
3. If a test is determined to be unnecessary, you can either remove it or mark it with a note explaining why it's not needed.
4. Regularly review this document to ensure test coverage is comprehensive and up-to-date.

Remember to commit changes to this document along with your test implementations to keep your test tracking in sync with your actual test suite.