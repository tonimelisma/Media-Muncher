import Foundation

@MainActor
class ImportProgress: ObservableObject {
    @Published private(set) var totalBytesToImport: Int64 = 0
    @Published private(set) var importedBytes: Int64 = 0
    @Published private(set) var importedFileCount: Int = 0
    @Published private(set) var totalFilesToImport: Int = 0
    @Published private(set) var importStartTime: Date?

    var elapsedSeconds: TimeInterval? {
        guard let start = importStartTime else { return nil }
        return Date().timeIntervalSince(start)
    }
    
    var remainingSeconds: TimeInterval? {
        guard let elapsed = elapsedSeconds, elapsed > 0, importedBytes > 0 else { return nil }
        let throughput = Double(importedBytes) / elapsed
        guard throughput > 0 else { return nil }
        let remainingBytes = Double(max(0, totalBytesToImport - importedBytes))
        return remainingBytes / throughput
    }

    func start(with filesToImport: [File]) {
        self.totalFilesToImport = filesToImport.count
        self.totalBytesToImport = filesToImport.reduce(0) { $0 + ($1.size ?? 0) }
        self.importedBytes = 0
        self.importedFileCount = 0
        self.importStartTime = Date()
    }
    
    func update(with completedFile: File) {
        if completedFile.status == .imported {
            self.importedFileCount += 1
            self.importedBytes += completedFile.size ?? 0
        }
    }
    
    // MARK: - Testing Support
    
    /// Test-specific start method with explicit start time for deterministic testing
    func startForTesting(with filesToImport: [File], startTime: Date) {
        self.totalFilesToImport = filesToImport.count
        self.totalBytesToImport = filesToImport.reduce(0) { $0 + ($1.size ?? 0) }
        self.importedBytes = 0
        self.importedFileCount = 0
        self.importStartTime = startTime
    }
    
    /// Test-specific elapsed time calculation with explicit current time
    func elapsedSecondsForTesting(currentTime: Date) -> TimeInterval? {
        guard let start = importStartTime else { return nil }
        return currentTime.timeIntervalSince(start)
    }
    
    /// Test-specific remaining time calculation with explicit current time
    func remainingSecondsForTesting(currentTime: Date) -> TimeInterval? {
        guard let elapsed = elapsedSecondsForTesting(currentTime: currentTime), 
              elapsed > 0, 
              importedBytes > 0 else { return nil }
        let throughput = Double(importedBytes) / elapsed
        guard throughput > 0 else { return nil }
        let remainingBytes = Double(max(0, totalBytesToImport - importedBytes))
        return remainingBytes / throughput
    }
    
    func finish() {
        self.importStartTime = nil
    }
} 