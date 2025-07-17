import Foundation
@testable import Media_Muncher

class MockLogManager: Logging {
    
    struct LogCall {
        let level: LogEntry.LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
    }
    
    var calls = [LogCall]()
    
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]?, completion: (() -> Void)?) {
        calls.append(LogCall(level: level, category: category, message: message, metadata: metadata))
        completion?()
    }
} 