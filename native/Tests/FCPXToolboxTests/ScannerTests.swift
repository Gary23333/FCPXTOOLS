import XCTest
@testable import FCPXToolbox

final class ScannerTests: XCTestCase {
    
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
    
    func testLibraryScanning() throws {
        // 1. Create a simulated .fcpbundle folder
        let libraryURL = tempDir.appendingPathComponent("TestProject.fcpbundle", isDirectory: true)
        try fm.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        
        // 2. Create Event 1 with Render Files
        let renderFilesURL = libraryURL.appendingPathComponent("Event 1/Render Files/Peaks Data", isDirectory: true)
        try fm.createDirectory(at: renderFilesURL, withIntermediateDirectories: true)
        let renderFile = renderFilesURL.appendingPathComponent("render1.data")
        let renderData = Data(repeating: 0, count: 1024) // 1KB
        try renderData.write(to: renderFile)
        
        // 3. Create Event 1 with Analysis Files
        let analysisFilesURL = libraryURL.appendingPathComponent("Event 1/Analysis Files", isDirectory: true)
        try fm.createDirectory(at: analysisFilesURL, withIntermediateDirectories: true)
        let analysisFile = analysisFilesURL.appendingPathComponent("analysis1.data")
        let analysisData = Data(repeating: 0, count: 2048) // 2KB
        try analysisData.write(to: analysisFile)
        
        // 4. Create Event 1 with Original Media (read-only cached item)
        let originalMediaURL = libraryURL.appendingPathComponent("Event 1/Original Media", isDirectory: true)
        try fm.createDirectory(at: originalMediaURL, withIntermediateDirectories: true)
        let mediaFile = originalMediaURL.appendingPathComponent("video.mov")
        let mediaData = Data(repeating: 0, count: 4096) // 4KB
        try mediaData.write(to: mediaFile)
        
        // 5. Run Scanner
        let scanner = FCPXScanner()
        let expectation = self.expectation(description: "Scan finished")
        
        var scanProgressCalled = false
        var projectFoundCalled = false
        
        let result = scanner.scan(root: tempDir, progress: { progress in
            scanProgressCalled = true
        }, projectFound: { project in
            projectFoundCalled = true
            XCTAssertEqual(project.name, "TestProject.fcpbundle")
            XCTAssertEqual(project.kind, .library)
        })
        
        expectation.fulfill()
        waitForExpectations(timeout: 2, handler: nil)
        
        // 6. Assert result details
        XCTAssertTrue(scanProgressCalled)
        XCTAssertTrue(projectFoundCalled)
        XCTAssertEqual(result.projects.count, 1)
        
        let project = result.projects.first!
        XCTAssertEqual(project.cacheGroups.count, 3) // Render, Analysis, Original
        
        let renderGroup = project.cacheGroups.first { $0.type == .renderFiles }
        XCTAssertNotNil(renderGroup)
        XCTAssertEqual(renderGroup?.bytes, 1024)
        
        let analysisGroup = project.cacheGroups.first { $0.type == .analysisFiles }
        XCTAssertNotNil(analysisGroup)
        XCTAssertEqual(analysisGroup?.bytes, 2048)
        
        let originalGroup = project.cacheGroups.first { $0.type == .originalMedia }
        XCTAssertNotNil(originalGroup)
        XCTAssertEqual(originalGroup?.bytes, 4096)
    }
}
