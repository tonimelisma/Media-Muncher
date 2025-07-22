import Foundation
@testable import Media_Muncher

class MockLogManager: Logging, @unchecked Sendable {
    struct LogCall {
        let level: LogEntry.LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
    }
    
    private let queue = DispatchQueue(label: "MockLogManager.calls")
    private var _calls = [LogCall]()
    
    var calls: [LogCall] {
        queue.sync { _calls }
    }
    
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String : String]?, completion: (@Sendable () -> Void)?) {
        queue.sync {
            _calls.append(LogCall(level: level, category: category, message: message, metadata: metadata))
        }
        completion?()
    }
    
    func clearCalls() {
        queue.sync {
            _calls.removeAll()
        }
    }
} 