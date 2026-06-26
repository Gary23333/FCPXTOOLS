import Foundation

public enum ColorItemType: String, Codable {
    case lut = "3D LUT"
    case colorPreset = "颜色预置"
}

public struct ColorItem: Identifiable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let displayName: String
    public let type: ColorItemType
    public let sizeBytes: Int64
    public let modifiedAt: Date?
}
