import Foundation

/// 归档状态
enum ArchiveStatus: String {
    case pending = "待归档"
    case archiving = "归档中"
    case archived = "已归档"
    case restoring = "恢复中"
    case failed = "失败"
}

/// 可归档的素材项（FCPX 资源库或媒体文件夹）
struct ArchivableItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let totalBytes: Int64
    let modifiedAt: Date?
    let fileCount: Int
    var status: ArchiveStatus
    var archivePath: String?  // 归档后的存储路径
}

/// 归档记录
struct ArchiveRecord: Identifiable, Codable {
    let id: UUID
    let originalName: String
    let originalPath: String
    let archivePath: String
    let totalBytes: Int64
    let archivedAt: Date
    let fileCount: Int
}
