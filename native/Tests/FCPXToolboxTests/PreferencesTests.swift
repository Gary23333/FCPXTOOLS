import XCTest
@testable import FCPXToolbox

final class PreferencesTests: XCTestCase {
    
    @MainActor
    override func setUp() {
        super.setUp()
        AppPreferences.shared.resetToDefaults()
    }
    
    @MainActor
    func testDefaultValues() {
        let prefs = AppPreferences.shared
        prefs.load()
        
        XCTAssertNil(prefs.defaultScanPath)
        XCTAssertTrue(prefs.confirmBeforeClean)
        XCTAssertEqual(prefs.appearanceMode, .system)
        XCTAssertTrue(prefs.checkUpdatesAutomatically)
        XCTAssertEqual(prefs.warnFreeSpaceBelowGB, 10.0)
        XCTAssertEqual(prefs.language, "system")
        XCTAssertEqual(prefs.startupSection, "清理助手")
    }
    
    @MainActor
    func testPreferencePersistence() {
        let prefs = AppPreferences.shared
        
        prefs.defaultScanPath = "/Users/test/Movies"
        prefs.confirmBeforeClean = false
        prefs.appearanceMode = .dark
        prefs.checkUpdatesAutomatically = false
        prefs.warnFreeSpaceBelowGB = 15.0
        prefs.language = "en"
        prefs.startupSection = "模板库"
        
        // Reload to simulate app restart
        prefs.load()
        
        XCTAssertEqual(prefs.defaultScanPath, "/Users/test/Movies")
        XCTAssertFalse(prefs.confirmBeforeClean)
        XCTAssertEqual(prefs.appearanceMode, .dark)
        XCTAssertFalse(prefs.checkUpdatesAutomatically)
        XCTAssertEqual(prefs.warnFreeSpaceBelowGB, 15.0)
        XCTAssertEqual(prefs.language, "en")
        XCTAssertEqual(prefs.startupSection, "模板库")
    }
    
    @MainActor
    func testResetToDefaults() {
        let prefs = AppPreferences.shared
        
        prefs.defaultScanPath = "/Users/test/Movies"
        prefs.confirmBeforeClean = false
        prefs.resetToDefaults()
        
        XCTAssertNil(prefs.defaultScanPath)
        XCTAssertTrue(prefs.confirmBeforeClean)
        XCTAssertEqual(prefs.appearanceMode, .system)
    }
}
