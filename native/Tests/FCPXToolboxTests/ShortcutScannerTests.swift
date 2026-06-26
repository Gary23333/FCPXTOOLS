import XCTest
@testable import FCPXToolbox

final class ShortcutScannerTests: XCTestCase {
    
    private let fm = FileManager.default
    private var tempPath: URL!
    private var tempExportPath: URL!
    
    override func setUp() {
        super.setUp()
        let id = UUID().uuidString
        tempPath = fm.temporaryDirectory.appendingPathComponent("commandsets_\(id)", isDirectory: true)
        tempExportPath = fm.temporaryDirectory.appendingPathComponent("export_\(id)", isDirectory: true)
        
        try? fm.createDirectory(at: tempPath, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: tempExportPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        try? fm.removeItem(at: tempPath)
        try? fm.removeItem(at: tempExportPath)
        super.tearDown()
    }
    
    func testShortcutScanningAndOperations() throws {
        // 1. Create simulated FCPX command set files
        let preset1 = tempPath.appendingPathComponent("CustomKeys.fcpxcmd")
        try Data("mock fcpxcmd".utf8).write(to: preset1)
        
        let preset2 = tempPath.appendingPathComponent("DefaultKeys.plist")
        try Data("mock plist".utf8).write(to: preset2)
        
        // 2. Scan
        let scanner = ShortcutScanner(path: tempPath)
        var items = scanner.scan()
        
        XCTAssertEqual(items.count, 2)
        
        let first = items.first { $0.name == "CustomKeys.fcpxcmd" }
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.displayName, "CustomKeys")
        XCTAssertEqual(first?.sizeBytes, 12)
        
        // 3. Export
        try scanner.exportPreset(first!, to: tempExportPath)
        let exportedFile = tempExportPath.appendingPathComponent("CustomKeys.fcpxcmd")
        XCTAssertTrue(fm.fileExists(atPath: exportedFile.path))
        
        // 4. Import
        let externalPreset = tempExportPath.appendingPathComponent("ExternalLayout.fcpxcmd")
        try Data("mock external".utf8).write(to: externalPreset)
        
        let importedURL = try scanner.importPreset(from: externalPreset)
        XCTAssertTrue(fm.fileExists(atPath: importedURL.path))
        XCTAssertEqual(importedURL.lastPathComponent, "ExternalLayout.fcpxcmd")
        
        // Re-scan
        items = scanner.scan()
        XCTAssertEqual(items.count, 3)
        
        // 5. Delete
        let importedItem = items.first { $0.name == "ExternalLayout.fcpxcmd" }
        XCTAssertNotNil(importedItem)
        try scanner.deletePreset(importedItem!)
        
        XCTAssertFalse(fm.fileExists(atPath: importedURL.path))
    }
}
