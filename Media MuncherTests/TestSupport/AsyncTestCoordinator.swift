//
//  AsyncTestCoordinator.swift
//  Media MuncherTests
//
//  Improved async test coordination helpers that eliminate race conditions
//  and provide consistent logging patterns across test files.
//

import XCTest
import Combine
import Foundation
@testable import Media_Muncher

// MARK: - Test Logging Infrastructure

extension XCTestCase {
    
    /// Provides consistent test logging with automatic test context
    var testLogger: Logging {
        // Return a shared MockLogManager for consistent test logging
        return MockLogManager.shared
    }
    
    /// Log a test step with automatic context and formatting
    func logTestStep(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) async {
        let testName = String(function.prefix(while: { $0 != "(" }))
        await testLogger.debug("🧪 [\(testName)] \(message)", category: "TestDebugging")
    }
}

// MARK: - Enhanced MockLogManager

extension MockLogManager {
    /// Shared instance for consistent test logging across all tests
    static let shared = MockLogManager()
}

// MARK: - Removed - Methods moved to MediaMuncherTestCase for proper scope access