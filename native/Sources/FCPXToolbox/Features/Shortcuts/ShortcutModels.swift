import Foundation

/// 快捷键预设文件数据模型。
public struct ShortcutItem: Identifiable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let displayName: String
    public let sizeBytes: Int64
    public let modifiedAt: Date?
}
