import Foundation

/// 插件类型。
public enum PluginType: String, Codable, CaseIterable {
    case fxPlug = "FxPlug 插件"
    case motionTemplate = "Motion 模板插件"
}

/// 插件存储位置。
public enum PluginLocation: String, Codable {
    case user = "用户目录"
    case system = "系统目录"
}

/// FxPlug 插件数据模型。
public struct PluginItem: Identifiable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let displayName: String
    public let type: PluginType
    public let location: PluginLocation
    public let sizeBytes: Int64
    public var isEnabled: Bool
}
