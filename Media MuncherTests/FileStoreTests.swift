import XCTest
@testable import Media_Muncher

@MainActor
final class FileStoreTests: XCTestCase {
    
    private var fileStore: FileStore!
    private var logManager: LogManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        logManager = LogManager()
        fileStore = FileStore(logManager: logManager)
    }
    
    override func tearDownWithError() throws {
        fileStore = nil
        logManager = nil
        try super.tearDownWithError()
    }
    
    func testInitialState() {
        XCTAssertTrue(fileStore.files.isEmpty)
        XCTAssertEqual(fileStore.fileCount, 0)
        XCTAssertTrue(fileStore.filesToImport.isEmpty)
        XCTAssertTrue(fileStore.importedFiles.isEmpty)
        XCTAssertTrue(fileStore.preExistingFiles.isEmpty)
    }
    
    func testSetFiles() {
        let files = [
            File(sourcePath: "/test/file1.jpg", mediaType: .image, size: 100, status: .waiting),
            File(sourcePath: "/test/file2.jpg", mediaType: .image, size: 200, status: .pre_existing)
        ]
        
        fileStore.setFiles(files)
        
        XCTAssertEqual(fileStore.files.count, 2)
        XCTAssertEqual(fileStore.fileCount, 2)
        XCTAssertEqual(fileStore.filesToImport.count, 1)
        XCTAssertEqual(fileStore.preExistingFiles.count, 1)
        XCTAssertEqual(fileStore.importedFiles.count, 0)
    }
    
    func testClearFiles() {
        let files = [
            File(sourcePath: "/test/file1.jpg", mediaType: .image, size: 100, status: .waiting)
        ]
        
        fileStore.setFiles(files)
        XCTAssertFalse(fileStore.files.isEmpty)
        
        fileStore.clearFiles()
        XCTAssertTrue(fileStore.files.isEmpty)
        XCTAssertEqual(fileStore.fileCount, 0)
    }
    
    func testUpdateFile() {
        let file = File(sourcePath: "/test/file1.jpg", mediaType: .image, size: 100, status: .waiting)
        fileStore.setFiles([file])
        
        var updatedFile = file
        updatedFile.status = .imported
        
        fileStore.updateFile(updatedFile)
        
        XCTAssertEqual(fileStore.files.count, 1)
        XCTAssertEqual(fileStore.files.first?.status, .imported)
        XCTAssertEqual(fileStore.filesToImport.count, 0)
        XCTAssertEqual(fileStore.importedFiles.count, 1)
    }
    
    func testUpdateFiles() {
        let files = [
            File(sourcePath: "/test/file1.jpg", mediaType: .image, size: 100, status: .waiting),
            File(sourcePath: "/test/file2.jpg", mediaType: .image, size: 200, status: .waiting)
        ]
        fileStore.setFiles(files)
        
        let updatedFiles = files.map { file in
            var updated = file
            updated.status = .imported
            return updated
        }
        
        fileStore.updateFiles(updatedFiles)
        
        XCTAssertEqual(fileStore.files.count, 2)
        XCTAssertEqual(fileStore.importedFiles.count, 2)
        XCTAssertEqual(fileStore.filesToImport.count, 0)
    }
    
    func testFileQuery() {
        let file = File(sourcePath: "/test/file1.jpg", mediaType: .image, size: 100, status: .waiting)
        fileStore.setFiles([file])
        
        let foundFile = fileStore.file(withId: file.id)
        XCTAssertNotNil(foundFile)
        XCTAssertEqual(foundFile?.id, file.id)
        
        let notFoundFile = fileStore.file(withId: "nonexistent")
        XCTAssertNil(notFoundFile)
    }
} 