import XCTest
import Foundation
import Combine
@testable import Media_Muncher

/// Specialized base class for integration tests requiring file system operations and service setup
class IntegrationTestCase: MediaMuncherTestCase {
    
    // MARK: - Common Integration Test Properties
    
    /// Source directory for test files (simulates removable volume)
    var sourceURL: URL!
    
    /// Destination directory for import operations
    var destinationURL: URL!
    
    /// Isolated settings store instance for testing
    var settingsStore: SettingsStore!
        
    // MARK: - Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create source and destination directories
        sourceURL = tempDirectory.appendingPathComponent("source")
        destinationURL = tempDirectory.appendingPathComponent("destination")
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        // Initialize isolated settings store
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        settingsStore = SettingsStore(logManager: MockLogManager.shared, userDefaults: testDefaults)
        
        // cancellables initialized in parent class
    }
    
    override func tearDownWithError() throws {
        // Clean up URLs - parent class handles tempDirectory removal
        sourceURL = nil
        destinationURL = nil
        settingsStore = nil
        // cancellables cleaned up in parent class
        
        try super.tearDownWithError()
    }
    
    // MARK: - Utility Methods
    
    /// Copies a test fixture from the bundle to the source directory
    func setupSourceFile(named fileName: String, in subfolder: String? = nil) throws -> URL {
        guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) else {
            throw TestError.fixtureNotFound(name: fileName)
        }
        
        var finalSourceURL = sourceURL!
        if let subfolder = subfolder {
            finalSourceURL = sourceURL.appendingPathComponent(subfolder)
            try fileManager.createDirectory(at: finalSourceURL, withIntermediateDirectories: true)
        }
        
        let destinationInSource = finalSourceURL.appendingPathComponent(fileName)
        try fileManager.copyItem(at: fixtureURL, to: destinationInSource)
        return destinationInSource
    }
    
    /// Creates a test volume with specified files
    func createTestVolume(withFiles fileNames: [String]) throws -> URL {
        let volumeURL = tempDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: volumeURL, withIntermediateDirectories: true)
        
        for fileName in fileNames {
            guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) else {
                throw TestError.fixtureNotFound(name: fileName)
            }
            try fileManager.copyItem(at: fixtureURL, to: volumeURL.appendingPathComponent(fileName))
        }
        return volumeURL
    }
    
    /// Collects all results from an async stream
    func collectStreamResults<T>(for stream: AsyncThrowingStream<T, Error>) async throws -> [T] {
        var results: [T] = []
        for try await item in stream {
            results.append(item)
        }
        return results
    }
}

/// Common test errors
enum TestError: Error, LocalizedError {
    case fixtureNotFound(name: String)
    
    var errorDescription: String? {
        switch self {
        case .fixtureNotFound(let name):
            return "Test fixture '\(name)' not found. Ensure it's added to the 'Media MuncherTests' target and its 'Copy Bundle Resources' build phase."
        }
    }
}