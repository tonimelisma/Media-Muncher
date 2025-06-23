@testable import Media_Muncher
import Foundation

class MockSecurityScopedURLAccessWrapper: SecurityScopedURLAccessWrapperProtocol {
    var startAccessingCalled = false
    var stopAccessingCalled = false
    var urlForStart: URL?
    var urlForStop: URL?
    
    var shouldReturn = true

    func startAccessingSecurityScopedResource(for url: URL) -> Bool {
        startAccessingCalled = true
        urlForStart = url
        return shouldReturn
    }

    func stopAccessingSecurityScopedResource(for url: URL) {
        stopAccessingCalled = true
        urlForStop = url
    }
} 