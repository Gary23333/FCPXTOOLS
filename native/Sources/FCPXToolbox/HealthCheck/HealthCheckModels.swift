import Foundation

/// 健康检查状态
enum HealthStatus: String {
    case healthy = "健康"
    case warning = "警告"
    case critical = "严重"
    case unknown = "未知"
}

/// 健康检查项
struct HealthCheckItem: Identifiable {
    let id = UUID()
    let title: String
    let status: HealthStatus
    let detail: String
    let recommendation: String?
}

/// 资源库健康报告
struct LibraryHealthReport: Identifiable {
    let id = UUID()
    let libraryName: String
    let libraryURL: URL
    let totalBytes: Int64
    let renderCacheBytes: Int64
    let originalMediaBytes: Int64
    let proxyMediaBytes: Int64
    let optimizedMediaBytes: Int64
    let modifiedAt: Date?
    let checkItems: [HealthCheckItem]

    var overallStatus: HealthStatus {
        if checkItems.contains(where: { $0.status == .critical }) { return .critical }
        if checkItems.contains(where: { $0.status == .warning }) { return .warning }
        return .healthy
    }
}
