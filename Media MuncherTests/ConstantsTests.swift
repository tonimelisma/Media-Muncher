//
//  ConstantsTests.swift
//  Media MuncherTests
//
//  Created by Claude on 2025-07-21.
//

import XCTest
@testable import Media_Muncher

final class ConstantsTests: XCTestCase {
    
    func testThumbnailCacheLimit() {
        XCTAssertEqual(Constants.thumbnailCacheLimit, 2000, "Thumbnail cache limit should be 2000 entries")
        XCTAssertGreaterThan(Constants.thumbnailCacheLimit, 0, "Cache limit must be positive")
    }
    
    func testTimestampProximityThreshold() {
        XCTAssertEqual(Constants.timestampProximityThreshold, 60, "Timestamp threshold should be 60 seconds")
        XCTAssertGreaterThan(Constants.timestampProximityThreshold, 0, "Threshold must be positive")
    }
    
    func testGridLayoutConstants() {
        XCTAssertEqual(Constants.gridColumnWidth, 120, "Grid column width should be 120 points")
        XCTAssertEqual(Constants.gridColumnSpacing, 10, "Grid spacing should be 10 points")
        XCTAssertEqual(Constants.gridPadding, 20, "Grid padding should be 20 points")
        
        // All layout constants should be positive
        XCTAssertGreaterThan(Constants.gridColumnWidth, 0)
        XCTAssertGreaterThan(Constants.gridColumnSpacing, 0)
        XCTAssertGreaterThan(Constants.gridPadding, 0)
    }
    
    func testLogRetentionPeriod() {
        let expectedSeconds = 30 * 24 * 3600 // 30 days
        XCTAssertEqual(Constants.logRetentionPeriod, TimeInterval(expectedSeconds), "Log retention should be 30 days")
    }
    
    func testCancellationCheckInterval() {
        XCTAssertEqual(Constants.cancellationCheckInterval, 1_000_000, "Cancellation check interval should be 1MB")
        XCTAssertGreaterThan(Constants.cancellationCheckInterval, 0, "Interval must be positive")
    }
    
    func testGridColumnsCountCalculation() {
        // Test with various window widths
        let testCases: [(width: CGFloat, expectedColumns: Int)] = [
            (150, 0),   // Too narrow for a column
            (300, 2),   // Small window
            (600, 4),   // Medium window
            (1200, 8),  // Large window
            (1920, 14)  // Very wide window
        ]
        
        for testCase in testCases {
            let actualColumns = Constants.gridColumnsCount(for: testCase.width)
            XCTAssertEqual(actualColumns, testCase.expectedColumns,
                          "Width \(testCase.width) should produce \(testCase.expectedColumns) columns, got \(actualColumns)")
            XCTAssertGreaterThanOrEqual(actualColumns, 0, "Columns count should never be negative")
        }
    }
    
    func testGridColumnsCountEdgeCases() {
        // Test edge cases
        XCTAssertEqual(Constants.gridColumnsCount(for: 0), 0, "Zero width should produce 0 columns")
        XCTAssertEqual(Constants.gridColumnsCount(for: -100), 0, "Negative width should produce 0 columns")
        
        // Test exact boundary case
        let exactBoundary = Constants.gridPadding * 2 + Constants.gridColumnWidth + Constants.gridColumnSpacing
        XCTAssertEqual(Constants.gridColumnsCount(for: exactBoundary), 1, "Exact boundary should produce 1 column")
    }
}
