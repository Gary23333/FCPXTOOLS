import XCTest
@testable import FCPXToolbox

final class PathUtilsTests: XCTestCase {
    
    func testFCPXPaths() {
        let userTemplates = FCPXPaths.userMotionTemplates
        let systemTemplates = FCPXPaths.systemMotionTemplates
        let userLUTs = FCPXPaths.userLUTs
        let colorPresets = FCPXPaths.colorPresets
        let userPlugins = FCPXPaths.userPlugins
        let systemPlugins = FCPXPaths.systemPlugins
        let commandSets = FCPXPaths.keyboardCommandSets
        let exportSettings = FCPXPaths.exportSettings
        let preferencesPlist = FCPXPaths.preferencesPlist
        
        XCTAssertTrue(userTemplates.path.contains("Movies/Motion Templates.localized"))
        XCTAssertEqual(systemTemplates.path, "/Library/Application Support/Final Cut Pro/Templates")
        XCTAssertTrue(userLUTs.path.contains("Library/Application Support/ProApps/Custom LUTs"))
        XCTAssertTrue(colorPresets.path.contains("Library/Application Support/ProApps/Color Presets"))
        XCTAssertTrue(userPlugins.path.contains("Library/Plug-Ins/FxPlug"))
        XCTAssertEqual(systemPlugins.path, "/Library/Plug-Ins/FxPlug")
        XCTAssertTrue(commandSets.path.contains("Library/Application Support/Final Cut Pro/Command Sets"))
        XCTAssertTrue(exportSettings.path.contains("Library/Application Support/ProApps/Export Settings"))
        XCTAssertTrue(preferencesPlist.path.contains("Library/Preferences/com.apple.FinalCut.plist"))
    }
}
