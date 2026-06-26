import Foundation

/// 扫描管理自定义 LUT 和颜色预置的服务类。
public final class ColorScanner {
    private let fm = FileManager.default
    
    private let customLUTsPath: URL?
    private let customPresetsPath: URL?
    
    public init(lutsPath: URL? = nil, presetsPath: URL? = nil) {
        self.customLUTsPath = lutsPath
        self.customPresetsPath = presetsPath
    }
    
    /// 扫描所有的色彩自定义项目。
    public func scan() -> [ColorItem] {
        var items: [ColorItem] = []
        
        let lutsDir = customLUTsPath ?? FCPXPaths.userLUTs
        let presetsDir = customPresetsPath ?? FCPXPaths.colorPresets
        
        scanLUTs(lutsDir, into: &items)
        scanPresets(presetsDir, into: &items)
        
        return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    
    /// 删除某个色彩自定义项目（安全移至废纸篓）。
    public func deleteItem(_ item: ColorItem) throws {
        var resultingURL: NSURL?
        try fm.trashItem(at: item.url, resultingItemURL: &resultingURL)
    }
    
    private func scanLUTs(_ dir: URL, into list: inout [ColorItem]) {
        // LUT 目录一般可能嵌套，所以做深度枚举
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for case let url as URL in enumerator {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            guard isFile else { continue }
            
            let ext = url.pathExtension.lowercased()
            // 常见的 LUT 格式
            guard ["cube", "mga", "m3d"].contains(ext) else { continue }
            
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate
            
            list.append(ColorItem(
                url: url,
                name: url.lastPathComponent,
                displayName: url.deletingPathExtension().lastPathComponent,
                type: .lut,
                sizeBytes: size,
                modifiedAt: modified
            ))
        }
    }
    
    private func scanPresets(_ dir: URL, into list: inout [ColorItem]) {
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for url in entries {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            guard isFile else { continue }
            
            let ext = url.pathExtension.lowercased()
            // 颜色预置一般是 plist 格式或没有后缀
            guard ext == "plist" || ext.isEmpty else { continue }
            
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate
            
            list.append(ColorItem(
                url: url,
                name: url.lastPathComponent,
                displayName: url.deletingPathExtension().lastPathComponent,
                type: .colorPreset,
                sizeBytes: size,
                modifiedAt: modified
            ))
        }
    }
}
