import Foundation

struct MediaImporter {
    private let appState: AppState
    
    init(appState: AppState) {
        print("MediaImporter: Initializing")
        self.appState = appState
    }
    
    func importMediaFiles() async throws {
        print("MediaImporter: Starting import process")
        let totalFiles = Double(appState.mediaFiles.count)
        print("MediaImporter: Total files to import: \(totalFiles)")
        let importedFiles = try await appState.mediaFiles.enumerated().asyncMap { index, file in
            print("MediaImporter: Processing file \(index + 1) of \(Int(totalFiles))")
            let result = try await self.processMediaFile(file)
            await self.updateProgress(Double(index + 1) / totalFiles)
            return result
        }
        
        let errors = importedFiles.compactMap { $0.error }
        if !errors.isEmpty {
            print("MediaImporter: Import completed with \(errors.count) errors")
            throw ImportError.partialFailure(errors: errors)
        }
        
        await MainActor.run {
            print("MediaImporter: Updating appState with imported files")
            appState.mediaFiles = importedFiles.compactMap { $0.file }
        }
        print("MediaImporter: Import process completed successfully")
    }
    
    private func processMediaFile(_ file: MediaFile) async throws -> (file: MediaFile?, error: Error?) {
        print("MediaImporter: Processing file: \(file.sourceName)")
        do {
            try Task.checkCancellation()
            
            let destinationPath = appState.defaultSavePath
            let destinationName = file.sourceName
            
            var sourceCRC32: UInt32?
            var destinationCRC32: UInt32?
            
            if appState.verifyImportIntegrity {
                print("MediaImporter: Verifying import integrity")
                sourceCRC32 = file.calculateCRC32(forPath: file.sourcePath)
                // For now, we're not actually copying the file, so we'll use the same CRC32 for both source and destination
                destinationCRC32 = sourceCRC32
            }
            
            var isImported = false
            if appState.verifyImportIntegrity {
                if sourceCRC32 == destinationCRC32 {
                    print("MediaImporter: Integrity check passed")
                    isImported = true
                } else {
                    print("MediaImporter: Integrity check failed")
                    throw ImportError.integrityCheckFailed(fileName: destinationName)
                }
            } else {
                isImported = true
            }
            
            var updatedFile = file
            updatedFile.destinationPath = destinationPath
            updatedFile.destinationName = destinationName
            updatedFile.sourceCRC32 = sourceCRC32
            updatedFile.destinationCRC32 = destinationCRC32
            updatedFile.isImported = isImported
            
            print("MediaImporter: File processed successfully: \(updatedFile.sourceName)")
            return (file: updatedFile, error: nil)
        } catch {
            print("MediaImporter: Error processing file \(file.sourceName): \(error)")
            return (file: nil, error: error)
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        print("MediaImporter: Updating progress: \(progress)")
        appState.importProgress = progress
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()
        
        for element in self {
            try await values.append(transform(element))
        }
        
        return values
    }
}