import XCTest
import Foundation
@testable import Media_Muncher

/// Base test case class for all Media Muncher tests providing common setup and utilities
class MediaMuncherTestCase: XCTestCase {
    
    // MARK: - Common Properties
    
    /// Temporary directory unique to this test instance
    var tempDirectory: URL!
    
    /// File manager instance for test file operations
    var fileManager: FileManager!
    
    // MARK: - Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDirectory)
        tempDirectory = nil
        fileManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Utility Methods
    
    /// Creates a test file with specified content at the given path
    func createTestFile(at url: URL, content: Data) throws {
        try content.write(to: url)
    }
    
    /// Creates a simple test file with minimal content
    func createTestFile(named fileName: String, in directory: URL? = nil) throws -> URL {
        let targetDirectory = directory ?? tempDirectory!
        let fileURL = targetDirectory.appendingPathComponent(fileName)
        let content = Data("test content".utf8)
        try content.write(to: fileURL)
        return fileURL
    }
}