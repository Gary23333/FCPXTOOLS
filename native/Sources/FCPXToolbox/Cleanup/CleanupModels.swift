import Foundation

enum ResourceKind: String {
    case library = "FCPX 资源库"
    case legacyProject = "旧版项目"
    case event = "FCPX 事件"
}

enum CacheType: String, CaseIterable {
    case renderFiles = "渲染文件"
    case analysisFiles = "分析文件"
    case waveformCache = "波形缓存"
    case thumbnailMedia = "缩略图缓存"
    case optimizedMedia = "优化媒体"
    case proxyMedia = "代理媒体"
    case sharedItems = "共享/导出文件"
    case originalMedia = "原始媒体"
}

enum CleanRisk: String {
    case safe = "安全"
    case confirm = "需确认"
    case readOnly = "只读"
}

struct ScanIssue: Identifiable {
    let id = UUID()
    let path: String
    let message: String
}

struct ScanProgress {
    var currentPath: String = ""
    var scannedDirectories: Int = 0
    var scannedFiles: Int = 0
    var discoveredProjects: Int = 0
    var totalBytes: Int64 = 0
    var cleanableBytes: Int64 = 0
    var issues: [ScanIssue] = []
    var isCancelled: Bool = false
}

struct CacheTarget {
    let url: URL
    let bytes: Int64
    let fileCount: Int
    let modifiedAt: Date?
}

final class CacheGroup: Identifiable {
    let id = UUID()
    let type: CacheType
    let title: String
    let explanation: String
    let risk: CleanRisk
    let defaultSelected: Bool
    let bytes: Int64
    let fileCount: Int
    let latestModifiedAt: Date?
    let targets: [CacheTarget]
    var isSelected: Bool

    init(type: CacheType, targets: [CacheTarget]) {
        self.type = type
        self.title = type.rawValue
        self.risk = CacheGroup.risk(for: type)
        self.defaultSelected = self.risk == .safe
        self.targets = targets
        self.bytes = targets.reduce(0) { $0 + $1.bytes }
        self.fileCount = targets.reduce(0) { $0 + $1.fileCount }
        self.latestModifiedAt = targets.compactMap(\.modifiedAt).max()
        self.explanation = CacheGroup.explanation(for: type)
        self.isSelected = defaultSelected && bytes > 0
    }

    var canClean: Bool {
        risk != .readOnly && bytes > 0
    }

    static func risk(for type: CacheType) -> CleanRisk {
        switch type {
        case .renderFiles, .analysisFiles, .waveformCache, .thumbnailMedia:
            return .safe
        case .optimizedMedia, .proxyMedia, .sharedItems:
            return .confirm
        case .originalMedia:
            return .readOnly
        }
    }

    static func explanation(for type: CacheType) -> String {
        switch type {
        case .renderFiles:
            return "FCPX 可重新生成。清理后部分片段可能需要重新渲染。"
        case .analysisFiles:
            return "稳定、人物、光流等分析缓存，可重新生成。"
        case .waveformCache:
            return "音频波形显示缓存，可重新生成。"
        case .thumbnailMedia:
            return "浏览缩略图缓存，可重新生成。"
        case .optimizedMedia:
            return "不影响原始素材，但可能降低剪辑流畅度，需要重新生成优化媒体。"
        case .proxyMedia:
            return "不影响原始素材，但代理剪辑工作流需要重新生成代理媒体。"
        case .sharedItems:
            return "可能包含用户导出的成片或共享文件，默认不选择。"
        case .originalMedia:
            return "原始素材只统计占用，不提供清理。"
        }
    }
}

final class ResourceItem: Identifiable {
    let id = UUID()
    let name: String
    let kind: ResourceKind
    let url: URL
    let totalBytes: Int64
    let modifiedAt: Date?
    let cacheGroups: [CacheGroup]
    let issues: [ScanIssue]

    init(name: String, kind: ResourceKind, url: URL, totalBytes: Int64, modifiedAt: Date?, cacheGroups: [CacheGroup], issues: [ScanIssue] = []) {
        self.name = name
        self.kind = kind
        self.url = url
        self.totalBytes = totalBytes
        self.modifiedAt = modifiedAt
        self.cacheGroups = cacheGroups
        self.issues = issues
    }

    var cleanableBytes: Int64 {
        cacheGroups.filter { $0.canClean }.reduce(0) { $0 + $1.bytes }
    }

    var selectedBytes: Int64 {
        cacheGroups.filter { $0.isSelected && $0.canClean }.reduce(0) { $0 + $1.bytes }
    }

    var selectedTargets: [CacheTarget] {
        cacheGroups.filter { $0.isSelected && $0.canClean }.flatMap(\.targets)
    }

    var originalMediaBytes: Int64 {
        cacheGroups.first { $0.type == .originalMedia }?.bytes ?? 0
    }
}

struct ScanResult {
    let root: URL
    let projects: [ResourceItem]
    let issues: [ScanIssue]
    let duration: TimeInterval

    var totalBytes: Int64 {
        projects.reduce(0) { $0 + $1.totalBytes }
    }

    var cleanableBytes: Int64 {
        projects.reduce(0) { $0 + $1.cleanableBytes }
    }

    var selectedBytes: Int64 {
        projects.reduce(0) { $0 + $1.selectedBytes }
    }
}
