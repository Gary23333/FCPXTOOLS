import Foundation

/// Motion 模板分类。原始名是 `<Category>.localized` 文件夹的英文基名。
enum TemplateCategory: String, CaseIterable, Identifiable {
    case effects = "Effects"
    case transitions = "Transitions"
    case titles = "Titles"
    case generators = "Generators"
    case compositions = "Compositions"

    var id: String { rawValue }

    /// 中文显示名（与 FCP 中文界面一致；Titles 即「字幕/标题」）。
    var displayName: String {
        switch self {
        case .effects: return "效果"
        case .transitions: return "转场"
        case .titles: return "字幕 / 标题"
        case .generators: return "发生器"
        case .compositions: return "合成"
        }
    }

    var systemImage: String {
        switch self {
        case .effects: return "wand.and.stars"
        case .transitions: return "rectangle.on.rectangle.angled"
        case .titles: return "textformat"
        case .generators: return "circle.grid.cross"
        case .compositions: return "square.stack.3d.up"
        }
    }
}

/// 模板来源根目录。
enum TemplateRoot: String {
    case user = "用户"
    case system = "系统"

    var isWritable: Bool { self == .user }
}

enum TemplateRootFilter: String, CaseIterable, Identifiable {
    case all = "全部来源"
    case user = "用户"
    case system = "系统"

    var id: String { rawValue }

    func matches(_ root: TemplateRoot) -> Bool {
        switch self {
        case .all: return true
        case .user: return root == .user
        case .system: return root == .system
        }
    }
}

enum TemplateSizeRange: String, CaseIterable, Identifiable {
    case all = "全部大小"
    case under10MB = "< 10 MB"
    case tenTo100MB = "10-100 MB"
    case hundredMBTo1GB = "100 MB-1 GB"
    case over1GB = "> 1 GB"

    var id: String { rawValue }

    func matches(_ bytes: Int64) -> Bool {
        let mb: Int64 = 1_024 * 1_024
        let gb: Int64 = 1_024 * mb
        switch self {
        case .all: return true
        case .under10MB: return bytes < 10 * mb
        case .tenTo100MB: return bytes >= 10 * mb && bytes < 100 * mb
        case .hundredMBTo1GB: return bytes >= 100 * mb && bytes < gb
        case .over1GB: return bytes >= gb
        }
    }
}

enum TemplateModifiedRange: String, CaseIterable, Identifiable {
    case all = "全部时间"
    case last7Days = "最近 7 天"
    case last30Days = "最近 30 天"
    case lastYear = "最近一年"
    case olderThanYear = "一年前"
    case unknown = "未知"

    var id: String { rawValue }

    func matches(_ date: Date?, now: Date = Date()) -> Bool {
        switch self {
        case .all:
            return true
        case .unknown:
            return date == nil
        case .last7Days:
            return date.map { $0 >= now.addingTimeInterval(-7 * 24 * 60 * 60) } ?? false
        case .last30Days:
            return date.map { $0 >= now.addingTimeInterval(-30 * 24 * 60 * 60) } ?? false
        case .lastYear:
            return date.map { $0 >= now.addingTimeInterval(-365 * 24 * 60 * 60) } ?? false
        case .olderThanYear:
            return date.map { $0 < now.addingTimeInterval(-365 * 24 * 60 * 60) } ?? false
        }
    }
}

/// 一个 Motion 模板（包含 `<name>.moti` 的文件夹）。
struct TemplateItem: Identifiable, Hashable {
    let id: URL                 // 模板文件夹 URL，天然唯一
    let folderName: String      // 文件夹真实名
    let displayName: String     // 经 .localized 解析的显示名
    let category: TemplateCategory
    let group: String           // 所属厂商/主题显示名（直接父级），无则「未分组」
    let motiURL: URL
    let posterURL: URL?         // large.png（必要时回退 small.png）
    let bytes: Int64
    let modifiedAt: Date?
    let root: TemplateRoot

    var folderURL: URL { id }
    var isWritable: Bool { root.isWritable }
}

/// 模板库扫描进度。
struct TemplateScanProgress {
    var currentPath: String = ""
    var discovered: Int = 0
    var totalBytes: Int64 = 0
}

/// 模板库扫描结果。
struct TemplateScanResult {
    let items: [TemplateItem]
    let duration: TimeInterval

    func items(in category: TemplateCategory) -> [TemplateItem] {
        items.filter { $0.category == category }
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}
