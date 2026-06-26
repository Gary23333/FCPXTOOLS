import Foundation

/// 扫描与管理 FCPX 快捷键配置预设的服务类。
public final class ShortcutScanner {
    private let fm = FileManager.default
    private let customPath: URL?
    
    public init(path: URL? = nil) {
        self.customPath = path
    }
    
    private var commandSetsURL: URL {
        customPath ?? FCPXPaths.keyboardCommandSets
    }
    
    /// 扫描所有的快捷键预设文件。
    public func scan() -> [ShortcutItem] {
        var items: [ShortcutItem] = []
        let dir = commandSetsURL
        
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        for url in entries {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            guard isFile else { continue }
            
            // FCPX 快捷键预设文件通常是 .fcpxcmd 扩展名或者是 .plist
            let ext = url.pathExtension.lowercased()
            guard ext == "fcpxcmd" || ext == "plist" || ext.isEmpty else { continue }
            
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate
            
            items.append(ShortcutItem(
                url: url,
                name: url.lastPathComponent,
                displayName: url.deletingPathExtension().lastPathComponent,
                sizeBytes: size,
                modifiedAt: modified
            ))
        }
        
        return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    
    /// 导入外部快捷键预设文件到 FCPX 配置目录。
    public func importPreset(from sourceURL: URL) throws -> URL {
        let dir = commandSetsURL
        
        // 确保目标文件夹存在
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        
        let destinationURL = dir.appendingPathComponent(sourceURL.lastPathComponent)
        
        if fm.fileExists(atPath: destinationURL.path) {
            // 如果已存在同名预设，尝试使用重命名避免冲突
            var counter = 1
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            var uniqueURL = destinationURL
            
            while fm.fileExists(atPath: uniqueURL.path) {
                counter += 1
                let newName = "\(baseName) (\(counter))\(ext.isEmpty ? "" : ".\(ext)")"
                uniqueURL = dir.appendingPathComponent(newName)
            }
            try fm.copyItem(at: sourceURL, to: uniqueURL)
            return uniqueURL
        } else {
            try fm.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        }
    }
    
    /// 将内部快捷键预设文件导出到外部指定目录。
    public func exportPreset(_ item: ShortcutItem, to destinationDirectory: URL) throws {
        let destinationURL = destinationDirectory.appendingPathComponent(item.name)
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.copyItem(at: item.url, to: destinationURL)
    }
    
    /// 删除快捷键预设文件（移至废纸篓）。
    public func deletePreset(_ item: ShortcutItem) throws {
        var resultingURL: NSURL?
        try fm.trashItem(at: item.url, resultingItemURL: &resultingURL)
    }
}
