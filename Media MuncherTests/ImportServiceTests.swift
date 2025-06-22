//
//  ImportServiceTests.swift
//  Media MuncherTests
//
//  Created by Gemini on 3/8/25.
//

import XCTest
@testable import Media_Muncher

// Create a mock for testing purposes
class MockFileManager: FileManagerProtocol {
    var copyItemCallCount = 0
    var copyItemSourceURL: URL?
    var copyItemDestinationURL: URL?
    var shouldThrowError = false
    
    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyItemCallCount += 1
        copyItemSourceURL = srcURL
        copyItemDestinationURL = dstURL
        
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Mock copy failed"])
        }
    }
}

class MockSecurityScopedURLAccessWrapper: SecurityScopedURLAccessWrapperProtocol {
    var startAccessingCallCount = 0
    var stopAccessingCallCount = 0
    var shouldReturn = true

    func startAccessingSecurityScopedResource(for url: URL) -> Bool {
        startAccessingCallCount += 1
        return shouldReturn
    }

    func stopAccessingSecurityScopedResource(for url: URL) {
        stopAccessingCallCount += 1
    }
}

final class ImportServiceTests: XCTestCase {

    var mockFileManager: MockFileManager!
    var mockURLAccessWrapper: MockSecurityScopedURLAccessWrapper!
    var importService: ImportService!

    override func setUpWithError() throws {
        mockFileManager = MockFileManager()
        mockURLAccessWrapper = MockSecurityScopedURLAccessWrapper()
        importService = ImportService(
            fileManager: mockFileManager!,
            urlAccessWrapper: mockURLAccessWrapper!
        )
    }

    override func tearDownWithError() throws {
        mockFileManager = nil
        mockURLAccessWrapper = nil
        importService = nil
    }

    func testImportFiles_Success() async throws {
        // Arrange
        let testFile = File(sourcePath: "/tmp/source/test.jpg", mediaType: .image, status: .waiting)
        let filesToImport = [testFile]
        let destinationURL = URL(fileURLWithPath: "/tmp/destination")

        // Act
        // In a real test, we would need to ensure destinationURL is accessible.
        // For this unit test, we're focused on the service's logic.
        // We'll assume startAccessingSecurityScopedResource works and returns true.
        // The importFiles method itself doesn't return a value to assert, so we check the mock.
        try await importService.importFiles(files: filesToImport, to: destinationURL)

        // Assert
        XCTAssertEqual(mockURLAccessWrapper.startAccessingCallCount, 1)
        XCTAssertEqual(mockFileManager.copyItemCallCount, 1)
        XCTAssertEqual(mockFileManager.copyItemSourceURL, URL(fileURLWithPath: testFile.sourcePath))
        XCTAssertEqual(mockFileManager.copyItemDestinationURL, destinationURL.appendingPathComponent("test.jpg"))
        XCTAssertFalse(mockFileManager.shouldThrowError)
        XCTAssertEqual(mockURLAccessWrapper.stopAccessingCallCount, 1)
    }
    
    func testImportFiles_CopyFailure() async {
        // Arrange
        mockFileManager.shouldThrowError = true
        let testFile = File(sourcePath: "/tmp/source/fail.jpg", mediaType: .image, status: .waiting)
        let filesToImport = [testFile]
        let destinationURL = URL(fileURLWithPath: "/tmp/destination")
        
        // Act & Assert
        do {
            try await importService.importFiles(files: filesToImport, to: destinationURL)
            XCTFail("ImportService should have thrown an error but did not.")
        } catch let error as ImportService.ImportError {
            // Assert that it's the correct type of error
            if case .copyFailed(let source, let destination, _) = error {
                XCTAssertEqual(source, URL(fileURLWithPath: testFile.sourcePath))
                XCTAssertEqual(destination, destinationURL.appendingPathComponent("fail.jpg"))
            } else {
                XCTFail("Caught wrong error type.")
            }
        } catch {
            XCTFail("Caught an unexpected error type: \(error)")
        }
        
        XCTAssertEqual(mockFileManager.copyItemCallCount, 1)
        XCTAssertEqual(mockURLAccessWrapper.startAccessingCallCount, 1)
        XCTAssertEqual(mockURLAccessWrapper.stopAccessingCallCount, 1)
    }

    func testImportFiles_DestinationAccessDenied() async {
        // Arrange
        mockURLAccessWrapper.shouldReturn = false
        let testFile = File(sourcePath: "/tmp/source/test.jpg", mediaType: .image, status: .waiting)
        let filesToImport = [testFile]
        let destinationURL = URL(fileURLWithPath: "/tmp/destination")

        // Act & Assert
        do {
            try await importService.importFiles(files: filesToImport, to: destinationURL)
            XCTFail("ImportService should have thrown a destinationNotReachable error but did not.")
        } catch let error as ImportService.ImportError {
            XCTAssertEqual(error, .destinationNotReachable)
        } catch {
            XCTFail("Caught an unexpected error type: \(error)")
        }

        XCTAssertEqual(mockURLAccessWrapper.startAccessingCallCount, 1)
        XCTAssertEqual(mockFileManager.copyItemCallCount, 0)
        XCTAssertEqual(mockURLAccessWrapper.stopAccessingCallCount, 0) // defer should not be called
    }

    func testImportFiles_WithEmptyFileList() async throws {
        // Arrange
        let filesToImport: [File] = []
        let destinationURL = URL(fileURLWithPath: "/tmp/destination")

        // Act
        try await importService.importFiles(files: filesToImport, to: destinationURL)

        // Assert
        XCTAssertEqual(mockURLAccessWrapper.startAccessingCallCount, 1)
        XCTAssertEqual(mockFileManager.copyItemCallCount, 0)
        XCTAssertEqual(mockURLAccessWrapper.stopAccessingCallCount, 1)
    }

    func testImportFiles_MultipleFiles_Success() async throws {
        // Arrange
        let testFile1 = File(sourcePath: "/tmp/source/test1.jpg", mediaType: .image, status: .waiting)
        let testFile2 = File(sourcePath: "/tmp/source/test2.mov", mediaType: .video, status: .waiting)
        let filesToImport = [testFile1, testFile2]
        let destinationURL = URL(fileURLWithPath: "/tmp/destination")

        // Act
        try await importService.importFiles(files: filesToImport, to: destinationURL)

        // Assert
        XCTAssertEqual(mockURLAccessWrapper.startAccessingCallCount, 1)
        XCTAssertEqual(mockFileManager.copyItemCallCount, 2)
        XCTAssertEqual(mockURLAccessWrapper.stopAccessingCallCount, 1)
    }
} 