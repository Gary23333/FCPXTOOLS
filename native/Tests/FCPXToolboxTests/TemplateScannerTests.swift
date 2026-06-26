import XCTest
@testable import FCPXToolbox

final class TemplateScannerTests: XCTestCase {
    
    private let fm = FileManager.default
    private var tempUserRoot: URL!
    private var tempSystemRoot: URL!
    
    override func setUp() {
        super.setUp()
        let id = UUID().uuidString
        tempUserRoot = fm.temporaryDirectory.appendingPathComponent("user_\(id)", isDirectory: true)
        tempSystemRoot = fm.temporaryDirectory.appendingPathComponent("system_\(id)", isDirectory: true)
        
        try? fm.createDirectory(at: tempUserRoot, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: tempSystemRoot, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        try? fm.removeItem(at: tempUserRoot)
        try? fm.removeItem(at: tempSystemRoot)
        super.tearDown()
    }
    
    func testTemplateScanning() throws {
        // 1. Create simulated user template: Titles -> Group A -> CustomTitle (.moti)
        let userTitleDir = tempUserRoot.appendingPathComponent("Titles.localized/Group A/CustomTitle", isDirectory: true)
        try fm.createDirectory(at: userTitleDir, withIntermediateDirectories: true)
        try Data().write(to: userTitleDir.appendingPathComponent("CustomTitle.moti"))
        try Data("mock image".utf8).write(to: userTitleDir.appendingPathComponent("large.png"))
        
        // 2. Create simulated system template: Effects -> Retro -> VHSEffect (.moef)
        let systemEffectDir = tempSystemRoot.appendingPathComponent("Effects.localized/Retro/VHSEffect", isDirectory: true)
        try fm.createDirectory(at: systemEffectDir, withIntermediateDirectories: true)
        try Data().write(to: systemEffectDir.appendingPathComponent("VHSEffect.moef"))
        
        // 3. Scan
        let scanner = TemplateScanner(userRoot: tempUserRoot, systemRoot: tempSystemRoot)
        let result = scanner.scan(progress: { _ in })
        
        // 4. Assert
        XCTAssertEqual(result.items.count, 2)
        
        let first = result.items.first { $0.category == .titles }
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.displayName, "CustomTitle")
        XCTAssertEqual(first?.group, "Group A")
        XCTAssertEqual(first?.root, .user)
        XCTAssertNotNil(first?.posterURL)
        
        let second = result.items.first { $0.category == .effects }
        XCTAssertNotNil(second)
        XCTAssertEqual(second?.displayName, "VHSEffect")
        XCTAssertEqual(second?.group, "Retro")
        XCTAssertEqual(second?.root, .system)
        XCTAssertNil(second?.posterURL) // No large.png or small.png was written
    }
}
