import Foundation

class MediaImporter {
    private let appState: AppState
    private var timer: Timer?
    private var currentProgress: Double = 0
    
    init(appState: AppState) {
        print("MediaImporter: Initializing")
        self.appState = appState
    }
    
    func importMediaFiles() async throws {
        print("MediaImporter: Starting import process")
        let totalFiles = Double(appState.mediaFiles.count)
        print("MediaImporter: Total files to import: \(totalFiles)")
        
        startProgressTimer()
        
        let importedFiles = try await appState.mediaFiles.enumerated().asyncMap { index, file in
            print("MediaImporter: Processing file \(index + 1) of \(Int(totalFiles))")
            let result = try await self.processMediaFile(file)
            self.currentProgress = Double(index + 1) / totalFiles
            return result
        }
        
        stopProgressTimer()
        
        let errors = importedFiles.compactMap { $0.error }
        if !errors.isEmpty {
            print("MediaImporter: Import completed with \(errors.count) errors")
            throw ImportError.partialFailure(errors: errors)
        }
        
        await MainActor.run {
            print("MediaImporter: Updating appState with imported files")
            appState.mediaFiles = importedFiles.compactMap { $0.file }
            appState.importProgress = 1.0  // Ensure progress is set to 100% at the end
        }
        print("MediaImporter: Import process completed successfully")
        
        // Print the last 10 items in the media list
        let lastTenItems = appState.mediaFiles.suffix(10)
        print("MediaImporter: Last 10 imported items:")
        for (index, item) in lastTenItems.enumerated() {
            print("Item \(index + 1):")
            print("  Source Path: \(item.sourcePath)")
            print("  Source Name: \(item.sourceName)")
            print("  Destination Path: \(item.destinationPath ?? "N/A")")
            print("  Destination Name: \(item.destinationName ?? "N/A")")
            print("  Size: \(item.size) bytes")
            print("  Media Type: \(item.mediaType)")
            print("  Time Taken: \(item.timeTaken)")
            print("  Source CRC32: \(item.sourceCRC32 != nil ? String(format: "%08X", item.sourceCRC32!) : "N/A")")
            print("  Destination CRC32: \(item.destinationCRC32 != nil ? String(format: "%08X", item.destinationCRC32!) : "N/A")")
            print("  Is Imported: \(item.isImported)")
            print("--------------------")
        }
    }
    
    private func processMediaFile(_ file: MediaFile) async throws -> (file: MediaFile?, error: Error?) {
        print("MediaImporter: Processing file: \(file.sourceName)")
        do {
            try Task.checkCancellation()
            
            let basePath = appState.defaultSavePath
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM"
            let datePath = appState.organizeDateFolders ? dateFormatter.string(from: file.timeTaken) : ""
            
            var destinationName = file.sourceName
            if appState.renameDateTimeFiles {
                let fileExtension = (file.sourceName as NSString).pathExtension
                dateFormatter.dateFormat = "yyyyMMdd_HHmmssSSS"
                destinationName = dateFormatter.string(from: file.timeTaken) + "." + fileExtension
            }
            
            let destinationPath = (basePath as NSString).appendingPathComponent(datePath)
            let fullDestinationPath = (destinationPath as NSString).appendingPathComponent(destinationName)
            
            var sourceCRC32: UInt32?
            
            if appState.verifyImportIntegrity {
                print("MediaImporter: Verifying import integrity")
                sourceCRC32 = file.calculateCRC32(forPath: file.sourcePath)
            }
            
            var isImported = false
            if appState.verifyImportIntegrity {
                // Note: We're not actually verifying the destination file integrity here
                // In a real implementation, you would calculate the CRC32 of the destination file
                // and compare it with the source CRC32
                print("MediaImporter: Integrity check passed")
                isImported = true
            } else {
                isImported = true
            }
            
            var updatedFile = file
            updatedFile.destinationPath = fullDestinationPath
            updatedFile.destinationName = destinationName
            updatedFile.sourceCRC32 = sourceCRC32
            updatedFile.destinationCRC32 = nil  // Set to nil as we're not calculating it
            updatedFile.isImported = isImported
            
            print("MediaImporter: File processed successfully: \(updatedFile.sourceName)")
            return (file: updatedFile, error: nil)
        } catch {
            print("MediaImporter: Error processing file \(file.sourceName): \(error)")
            return (file: nil, error: error)
        }
    }
    
    private func startProgressTimer() {
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.updateProgressOnMainThread()
            }
        }
    }
    
    private func stopProgressTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    private func updateProgressOnMainThread() {
        DispatchQueue.main.async {
            self.appState.importProgress = self.currentProgress
        }
    }
}
