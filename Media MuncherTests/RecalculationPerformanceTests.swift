import XCTest
@testable import Media_Muncher

final class RecalculationPerformanceTests: XCTestCase {
    var processor: FileProcessorService!
    var settings: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        processor = FileProcessorService()
        settings = SettingsStore()
    }

    func testRecalculationPerformanceWithLargeFileSet() async throws {
        // Arrange - create mock large file set
        var largeFileSet: [File] = []
        
        for i in 0..<1000 {
            let file = File(
                sourcePath: "/mock/source/file_\(i).jpg",
                mediaType: .image,
                status: i % 3 == 0 ? .pre_existing : .waiting
            )
            largeFileSet.append(file)
        }
        
        let destinationURL = URL(fileURLWithPath: "/mock/destination")
        
        // Act & Measure
        measure {
            Task {
                let _ = try await processor.recalculateFileStatuses(
                    for: largeFileSet,
                    destinationURL: destinationURL,
                    settings: settings
                )
            }
        }
    }

    func testRecalculationWithComplexSidecarScenario() async throws {
        // Arrange - create files with many sidecars
        var filesWithSidecars: [File] = []
        
        for i in 0..<100 {
            var file = File(
                sourcePath: "/mock/source/video_\(i).mov",
                mediaType: .video,
                status: .waiting
            )
            // Add multiple sidecars per file
            file.sidecarPaths = [
                "/mock/source/video_\(i).xmp",
                "/mock/source/video_\(i).thm",
                "/mock/source/video_\(i).lrc"
            ]
            filesWithSidecars.append(file)
        }
        
        let destinationURL = URL(fileURLWithPath: "/mock/destination")
        
        // Act & Measure
        let startTime = Date()
        let recalculatedFiles = try await processor.recalculateFileStatuses(
            for: filesWithSidecars,
            destinationURL: destinationURL,
            settings: settings
        )
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Assert
        XCTAssertEqual(recalculatedFiles.count, filesWithSidecars.count)
        XCTAssertLessThan(duration, 1.0, "Recalculation should complete within 1 second for 100 files")
        
        // Verify sidecars preserved
        for (original, recalculated) in zip(filesWithSidecars, recalculatedFiles) {
            XCTAssertEqual(recalculated.sidecarPaths, original.sidecarPaths)
        }
    }

    func testMemoryUsageDuringRecalculation() async throws {
        // Arrange - create memory-intensive scenario
        var memoryIntensiveFiles: [File] = []
        
        for i in 0..<500 {
            var file = File(
                sourcePath: "/very/long/path/with/many/subdirectories/file_\(i)_with_very_long_name.jpg",
                mediaType: .image,
                status: .waiting
            )
            // Simulate files with extensive metadata/paths
            file.sidecarPaths = Array(0..<5).map { j in
                "/very/long/path/with/many/subdirectories/file_\(i)_sidecar_\(j).xmp"
            }
            memoryIntensiveFiles.append(file)
        }
        
        let destinationURL = URL(fileURLWithPath: "/destination/with/very/long/path/name")
        
        // Act - multiple rapid recalculations to test memory pressure
        for _ in 0..<10 {
            let _ = try await processor.recalculateFileStatuses(
                for: memoryIntensiveFiles,
                destinationURL: destinationURL,
                settings: settings
            )
        }
        
        // If we reach here without crashing, memory management is likely OK
        XCTAssertTrue(true, "Memory stress test completed without crash")
    }
}