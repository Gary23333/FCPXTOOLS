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
