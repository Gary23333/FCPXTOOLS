import Foundation

/// 输出目标类型
enum DestinationType: String {
    case exportFile = "导出文件"
    case youTube = "YouTube"
    case vimeo = "Vimeo"
    case appleDevices = "Apple 设备"
    case dvd = "DVD"
    case bluRay = "蓝光"
    case masterFile = "母版文件"
    case audioOnly = "仅音频"
    case custom = "自定义"
    case unknown = "未知"

    var systemImage: String {
        switch self {
        case .exportFile: return "square.and.arrow"
        case .youTube: return "play.rectangle"
        case .vimeo: return "play.rectangle.fill"
        case .appleDevices: return "applelogo"
        case .dvd: return "opticaldiscdrive"
        case .bluRay: return "opticaldiscdrive.fill"
        case .masterFile: return "film"
        case .audioOnly: return "waveform"
        case .custom: return "wrench.and.screwdriver"
        case .unknown: return "questionmark.folder"
        }
    }
}

/// 输出目标项
struct DestinationItem: Identifiable {
    let id = UUID()
    let name: String
    let type: DestinationType
    let fileURL: URL
    let format: String
    let resolution: String
    let isDefault: Bool
    let modifiedAt: Date?
    let isCustom: Bool  // 是否为用户自定义

    /// 从 plist 文件解析
    /// FCPX 的 destination plist 结构：
    /// Root dict 包含 "Name" -> String, "Type" -> String 等
    static func from(url: URL) -> DestinationItem? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let name = plist["Name"] as? String ?? url.deletingPathExtension().lastPathComponent
        let typeString = plist["Type"] as? String ?? ""
        let format = plist["Format"] as? String ?? plist["FFEncodedProfileName"] as? String ?? "默认"
        let resolution = plist["Resolution"] as? String ?? "默认"

        let type: DestinationType
        switch typeString.lowercased() {
        case let s where s.contains("youtube"): type = .youTube
        case let s where s.contains("vimeo"): type = .vimeo
        case let s where s.contains("apple"): type = .appleDevices
        case let s where s.contains("dvd"): type = .dvd
        case let s where s.contains("bluray") || s.contains("blu_ray"): type = .bluRay
        case let s where s.contains("master"): type = .masterFile
        case let s where s.contains("audio"): type = .audioOnly
        case let s where s.contains("export"): type = .exportFile
        default: type = name.lowercased().contains("youtube") ? .youTube :
                     name.lowercased().contains("vimeo") ? .vimeo :
                     name.lowercased().contains("dvd") ? .dvd :
                     name.lowercased().contains("apple") ? .appleDevices :
                     name.lowercased().contains("母版") || name.lowercased().contains("master") ? .masterFile :
                     name.lowercased().contains("音频") || name.lowercased().contains("audio") ? .audioOnly : .custom
        }

        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let isDefault = plist["IsDefault"] as? Bool ?? false

        return DestinationItem(
            name: name,
            type: type,
            fileURL: url,
            format: format,
            resolution: resolution,
            isDefault: isDefault,
            modifiedAt: modifiedAt,
            isCustom: true
        )
    }
}

/// 预设输出目标模板（用于创建新的输出目标）
struct DestinationPreset: Identifiable {
    let id = UUID()
    let name: String
    let type: DestinationType
    let description: String
    let defaultFormat: String
    let defaultResolution: String
}
