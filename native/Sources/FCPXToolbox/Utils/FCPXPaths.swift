import Foundation

/// Final Cut Pro X 常用文件系统路径配置中心。
public struct FCPXPaths {
    
    /// 获取用户主目录。
    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
    
    // MARK: - Motion Templates 路径
    
    /// 用户 Motion 模板目录：~/Movies/Motion Templates.localized
    public static var userMotionTemplates: URL {
        homeDirectory.appendingPathComponent("Movies/Motion Templates.localized")
    }
    
    /// 系统 Motion 模板目录：/Library/Application Support/Final Cut Pro/Templates
    public static var systemMotionTemplates: URL {
        URL(fileURLWithPath: "/Library/Application Support/Final Cut Pro/Templates")
    }
    
    // MARK: - Color & LUT 路径
    
    /// 用户自定义 LUT 目录：~/Library/Application Support/ProApps/Custom LUTs
    public static var userLUTs: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/ProApps/Custom LUTs")
    }
    
    /// 颜色预置目录：~/Library/Application Support/ProApps/Color Presets
    public static var colorPresets: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/ProApps/Color Presets")
    }
    
    // MARK: - FxPlug 插件路径
    
    /// 用户 FxPlug 插件目录：~/Library/Plug-Ins/FxPlug
    public static var userPlugins: URL {
        homeDirectory.appendingPathComponent("Library/Plug-Ins/FxPlug")
    }
    
    /// 系统 FxPlug 插件目录：/Library/Plug-Ins/FxPlug
    public static var systemPlugins: URL {
        URL(fileURLWithPath: "/Library/Plug-Ins/FxPlug")
    }
    
    // MARK: - Shortcuts 快捷键配置路径
    
    /// 快捷键预设目录：~/Library/Application Support/Final Cut Pro/Command Sets
    public static var keyboardCommandSets: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/Final Cut Pro/Command Sets")
    }
    
    // MARK: - Export Settings 导出设置路径
    
    /// 输出目标 (Destinations) 导出配置文件目录：~/Library/Application Support/ProApps/Export Settings
    public static var exportSettings: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/ProApps/Export Settings")
    }
    
    // MARK: - Final Cut Pro 偏好设置
    
    /// Final Cut Pro X 偏好 plist 路径：~/Library/Preferences/com.apple.FinalCut.plist
    public static var preferencesPlist: URL {
        homeDirectory.appendingPathComponent("Library/Preferences/com.apple.FinalCut.plist")
    }
}
