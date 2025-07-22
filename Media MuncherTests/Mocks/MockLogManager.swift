import Foundation
@testable import Media_Muncher

class MockLogManager: Logging, @unchecked Sendable {
    struct LogCall {
        let level: LogEntry.LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
    }
    
    actor State {
        var calls = [LogCall]()
        
        func recordCall(level: LogEntry.LogLevel, category: String, message: String, metadata: [String : String]?) {
            calls.append(LogCall(level: level, category: category, message: message, metadata: metadata))
        }
        
        func clear() {
            calls.removeAll()
        }
    }
    
    private let state = State()

    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String : String]?) async {
        await state.recordCall(level: level, category: category, message: message, metadata: metadata)
    }
    
    func getCalls() async -> [LogCall] {
        await state.calls
    }
    
    func clearCalls() async {
        await state.clear()
    }
} 