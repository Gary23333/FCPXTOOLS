import XCTest
@testable import FCPXToolbox

final class CleanerTests: XCTestCase {
    
    private let fm = FileManager.default
    private var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        try? fm.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testCleanerCore() throws {
        // Create 2 targets to clean
        let target1URL = tempDir.appendingPathComponent("target1")
        let target2URL = tempDir.appendingPathComponent("target2")
        try fm.createDirectory(at: target1URL, withIntermediateDirectories: true)
        try fm.createDirectory(at: target2URL, withIntermediateDirectories: true)
        
        try Data("target1 data".utf8).write(to: target1URL.appendingPathComponent("data.txt"))
        try Data("target2 data long".utf8).write(to: target2URL.appendingPathComponent("data2.txt"))
        
        let target1 = CacheTarget(url: target1URL, bytes: 12, fileCount: 1, modifiedAt: Date())
        let target2 = CacheTarget(url: target2URL, bytes: 17, fileCount: 1, modifiedAt: Date())
        
        let cleaner = FCPXCleanerCore()
        
        var progressCalledCount = 0
        let result = cleaner.clean(targets: [target1, target2]) { progress in
            progressCalledCount += 1
            XCTAssertLessThanOrEqual(progress.completed, progress.total)
        }
        
        XCTAssertTrue(progressCalledCount >= 2)
        XCTAssertEqual(result.cleanedBytes, 29)
        XCTAssertEqual(result.succeeded, 2)
        XCTAssertEqual(result.failed.count, 0)
        
        // Verify files are no longer in their original paths
        XCTAssertFalse(fm.fileExists(atPath: target1URL.path))
        XCTAssertFalse(fm.fileExists(atPath: target2URL.path))
    }
}
