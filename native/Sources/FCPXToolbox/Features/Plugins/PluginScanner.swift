import Foundation

/// 扫描与管理 FxPlug 插件的服务类。
public final class PluginScanner {
    private let fm = FileManager.default
    
    private let customUserPath: URL?
    private let customSystemPath: URL?
    
    public init(userPath: URL? = nil, systemPath: URL? = nil) {
        self.customUserPath = userPath
        self.customSystemPath = systemPath
    }
    
    /// 扫描可用插件。
    public func scan() -> [PluginItem] {
        var items: [PluginItem] = []
        
        let userDir = customUserPath ?? FCPXPaths.userPlugins
        let systemDir = customSystemPath ?? FCPXPaths.systemPlugins
        
        scanPath(userDir, location: .user, into: &items)
        scanPath(systemDir, location: .system, into: &items)
        
        return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    
    /// 切换插件启用状态（通过添加/移除 .disabled 后缀）。
    public func togglePlugin(_ plugin: PluginItem) throws -> URL {
        let isEnabled = plugin.isEnabled
        let sourceURL = plugin.url
        let targetURL: URL
        
        if isEnabled {
            // 禁用：MyPlugin.fxplug -> MyPlugin.fxplug.disabled
            targetURL = sourceURL.appendingPathExtension("disabled")
        } else {
            // 启用：MyPlugin.fxplug.disabled -> MyPlugin.fxplug
            targetURL = sourceURL.deletingPathExtension()
        }
        
        try fm.moveItem(at: sourceURL, to: targetURL)
        return targetURL
    }
    
    /// 删除插件（安全移至废纸篓）。
    public func deletePlugin(_ plugin: PluginItem) throws {
        var resultingURL: NSURL?
        try fm.trashItem(at: plugin.url, resultingItemURL: &resultingURL)
    }
    
    private func scanPath(_ dir: URL, location: PluginLocation, into list: inout [PluginItem]) {
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for url in entries {
            let filename = url.lastPathComponent
            let isFxPlug = filename.hasSuffix(".fxplug")
            let isFxPlugDisabled = filename.hasSuffix(".fxplug.disabled")
            
            guard isFxPlug || isFxPlugDisabled else { continue }
            
            let isEnabled = isFxPlug
            let cleanName = isEnabled ? filename : String(filename.dropLast(9)) // remove .disabled
            let displayName = url.deletingPathExtension().deletingPathExtension().lastPathComponent
            
            // 测量大小
            let size = measure(url)
            
            list.append(PluginItem(
                url: url,
                name: cleanName,
                displayName: displayName,
                type: .fxPlug,
                location: location,
                sizeBytes: size,
                isEnabled: isEnabled
            ))
        }
    }
    
    private func measure(_ url: URL) -> Int64 {
        var bytes: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let file as URL in enumerator {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            bytes += Int64(size)
        }
        return bytes
    }
}
