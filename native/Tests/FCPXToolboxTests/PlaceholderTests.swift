import XCTest
@testable import FCPXToolbox

/// 占位测试，保证测试 target 可构建。阶段 2-4 补充扫描规则、显示名解析、启停可逆性等用例。
final class PlaceholderTests: XCTestCase {
    func testCacheRiskMapping() {
        XCTAssertEqual(CacheGroup.risk(for: .renderFiles), .safe)
        XCTAssertEqual(CacheGroup.risk(for: .proxyMedia), .confirm)
        XCTAssertEqual(CacheGroup.risk(for: .originalMedia), .readOnly)
    }
}
