import XCTest
@testable import FCPXToolbox

final class ColorScannerTests: XCTestCase {
    
    private let fm = FileManager.default
    private var tempLUTsRoot: URL!
    private var tempPresetsRoot: URL!
    
    override func setUp() {
        super.setUp()
        let id = UUID().uuidString
        tempLUTsRoot = fm.temporaryDirectory.appendingPathComponent("luts_\(id)", isDirectory: true)
        tempPresetsRoot = fm.temporaryDirectory.appendingPathComponent("presets_\(id)", isDirectory: true)
        
        try? fm.createDirectory(at: tempLUTsRoot, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: tempPresetsRoot, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        try? fm.removeItem(at: tempLUTsRoot)
        try? fm.removeItem(at: tempPresetsRoot)
        super.tearDown()
    }
    
    func testColorScanningAndDeletion() throws {
        // 1. Create simulated LUT file: MockLUT.cube
        let lutURL = tempLUTsRoot.appendingPathComponent("MockLUT.cube")
        try Data("mock cube content".utf8).write(to: lutURL)
        
        // 2. Create simulated Preset file: MockPreset.plist
        let presetURL = tempPresetsRoot.appendingPathComponent("MockPreset.plist")
        try Data("mock plist content".utf8).write(to: presetURL)
        
        // 3. Scan
        let scanner = ColorScanner(lutsPath: tempLUTsRoot, presetsPath: tempPresetsRoot)
        let items = scanner.scan()
        
        // 4. Assert scanning results
        XCTAssertEqual(items.count, 2)
        
        let lutItem = items.first { $0.type == .lut }
        XCTAssertNotNil(lutItem)
        XCTAssertEqual(lutItem?.displayName, "MockLUT")
        XCTAssertEqual(lutItem?.name, "MockLUT.cube")
        
        let presetItem = items.first { $0.type == .colorPreset }
        XCTAssertNotNil(presetItem)
        XCTAssertEqual(presetItem?.displayName, "MockPreset")
        XCTAssertEqual(presetItem?.name, "MockPreset.plist")
        
        // 5. Test Deletion
        try scanner.deleteItem(lutItem!)
        XCTAssertFalse(fm.fileExists(atPath: lutURL.path))
    }
}
