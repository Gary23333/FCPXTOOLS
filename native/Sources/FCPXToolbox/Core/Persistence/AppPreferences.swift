import Foundation
import Combine

/// 应用的外观模式枚举。
public enum AppearanceMode: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

/// 日志级别枚举。
public enum LogLevel: String, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
}

/// 统一的偏好设置管理系统。
@MainActor
public final class AppPreferences: ObservableObject {
    public static let shared = AppPreferences()
    
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Keys
    private struct Keys {
        static let defaultScanPath = "defaultScanPath"
        static let confirmBeforeClean = "confirmBeforeClean"
        static let appearanceMode = "appearanceMode"
        static let checkUpdatesAutomatically = "checkUpdatesAutomatically"
        static let warnFreeSpaceBelowGB = "warnFreeSpaceBelowGB"
        static let language = "language"
        static let startupSection = "startupSection"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    // MARK: - Published Properties
    
    @Published public var defaultScanPath: String? = nil {
        didSet {
            defaults.set(defaultScanPath, forKey: Keys.defaultScanPath)
        }
    }
    
    @Published public var confirmBeforeClean: Bool = true {
        didSet {
            defaults.set(confirmBeforeClean, forKey: Keys.confirmBeforeClean)
        }
    }
    
    @Published public var appearanceMode: AppearanceMode = .system {
        didSet {
            if let encoded = try? JSONEncoder().encode(appearanceMode) {
                defaults.set(encoded, forKey: Keys.appearanceMode)
            }
        }
    }
    
    @Published public var checkUpdatesAutomatically: Bool = true {
        didSet {
            defaults.set(checkUpdatesAutomatically, forKey: Keys.checkUpdatesAutomatically)
        }
    }
    
    @Published public var warnFreeSpaceBelowGB: Double = 10.0 {
        didSet {
            defaults.set(warnFreeSpaceBelowGB, forKey: Keys.warnFreeSpaceBelowGB)
        }
    }
    
    @Published public var language: String = "system" {
        didSet {
            defaults.set(language, forKey: Keys.language)
        }
    }
    
    @Published public var startupSection: String = "清理助手" {
        didSet {
            defaults.set(startupSection, forKey: Keys.startupSection)
        }
    }
    
    @Published public var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }
    
    /// 加载默认设置或已存配置。
    public func load() {
        self.defaultScanPath = defaults.string(forKey: Keys.defaultScanPath)
        self.confirmBeforeClean = defaults.object(forKey: Keys.confirmBeforeClean) as? Bool ?? true
        
        if let data = defaults.data(forKey: Keys.appearanceMode),
           let mode = try? JSONDecoder().decode(AppearanceMode.self, from: data) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
        
        self.checkUpdatesAutomatically = defaults.object(forKey: Keys.checkUpdatesAutomatically) as? Bool ?? true
        self.warnFreeSpaceBelowGB = defaults.double(forKey: Keys.warnFreeSpaceBelowGB) == 0 ? 10.0 : defaults.double(forKey: Keys.warnFreeSpaceBelowGB)
        self.language = defaults.string(forKey: Keys.language) ?? "system"
        self.startupSection = defaults.string(forKey: Keys.startupSection) ?? "清理助手"
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
    
    /// 重置为出厂默认设置。
    public func resetToDefaults() {
        defaultScanPath = nil
        confirmBeforeClean = true
        appearanceMode = .system
        checkUpdatesAutomatically = true
        warnFreeSpaceBelowGB = 10.0
        language = "system"
        startupSection = "清理助手"
        hasCompletedOnboarding = false
    }
}
