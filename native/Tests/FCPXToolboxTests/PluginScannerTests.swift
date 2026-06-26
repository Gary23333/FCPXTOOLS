import XCTest
@testable import FCPXToolbox

final class PluginScannerTests: XCTestCase {
    
    private let fm = FileManager.default
    private var tempUserPath: URL!
    private var tempSystemPath: URL!
    
    override func setUp() {
        super.setUp()
        let id = UUID().uuidString
        tempUserPath = fm.temporaryDirectory.appendingPathComponent("user_plugins_\(id)", isDirectory: true)
        tempSystemPath = fm.temporaryDirectory.appendingPathComponent("system_plugins_\(id)", isDirectory: true)
        
        try? fm.createDirectory(at: tempUserPath, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: tempSystemPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        try? fm.removeItem(at: tempUserPath)
        try? fm.removeItem(at: tempSystemPath)
        super.tearDown()
    }
    
    func testPluginScanningAndToggling() throws {
        // 1. Create mock FxPlug plugins
        let userPluginDir = tempUserPath.appendingPathComponent("MockUserPlugin.fxplug", isDirectory: true)
        try fm.createDirectory(at: userPluginDir, withIntermediateDirectories: true)
        try Data("mock data".utf8).write(to: userPluginDir.appendingPathComponent("binary"))
        
        let systemPluginDir = tempSystemPath.appendingPathComponent("MockSystemPlugin.fxplug.disabled", isDirectory: true)
        try fm.createDirectory(at: systemPluginDir, withIntermediateDirectories: true)
        try Data("mock data 2".utf8).write(to: systemPluginDir.appendingPathComponent("binary2"))
        
        // 2. Scan
        let scanner = PluginScanner(userPath: tempUserPath, systemPath: tempSystemPath)
        var items = scanner.scan()
        
        XCTAssertEqual(items.count, 2)
        
        let userPlugin = items.first { $0.location == .user }
        XCTAssertNotNil(userPlugin)
        XCTAssertEqual(userPlugin?.displayName, "MockUserPlugin")
        XCTAssertEqual(userPlugin?.isEnabled, true)
        
        let systemPlugin = items.first { $0.location == .system }
        XCTAssertNotNil(systemPlugin)
        XCTAssertEqual(systemPlugin?.displayName, "MockSystemPlugin")
        XCTAssertEqual(systemPlugin?.isEnabled, false)
        
        // 3. Toggle user plugin (disable it)
        let newURL = try scanner.togglePlugin(userPlugin!)
        XCTAssertTrue(newURL.lastPathComponent.hasSuffix(".disabled"))
        XCTAssertTrue(fm.fileExists(atPath: newURL.path))
        
        // 4. Re-scan
        items = scanner.scan()
        let toggledUserPlugin = items.first { $0.displayName == "MockUserPlugin" }
        XCTAssertNotNil(toggledUserPlugin)
        XCTAssertEqual(toggledUserPlugin?.isEnabled, false)
        XCTAssertEqual(toggledUserPlugin?.url.lastPathComponent, "MockUserPlugin.fxplug.disabled")
        
        // 5. Test Deletion of system plugin
        try scanner.deletePlugin(systemPlugin!)
        XCTAssertFalse(fm.fileExists(atPath: systemPluginDir.path))
    }
}
