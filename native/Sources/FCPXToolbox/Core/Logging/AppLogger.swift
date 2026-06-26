import Foundation
import OSLog

/// FCPX 工具箱统一日志管理类。
/// 支持控制台 OSLog 分级输出与每日滚动日志文件持久化。
public final class AppLogger {
    private static let subsystem = "com.gary.fcpx-toolbox"
    private static let category = "App"
    private static let logger = Logger(subsystem: subsystem, category: category)
    
    /// 获取日志落盘的文件路径：~/Library/Logs/FCPXToolbox/fcpx-toolbox-YYYY-MM-DD.log
    public static let logFileURL: URL? = {
        let fm = FileManager.default
        guard let libraryURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let logDir = libraryURL.appendingPathComponent("Logs/FCPXToolbox", isDirectory: true)
        
        do {
            try fm.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return logDir.appendingPathComponent("fcpx-toolbox-\(dateString).log")
    }()
    
    public static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        writeLogEntry(level: "DEBUG", message: message)
    }
    
    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        writeLogEntry(level: "INFO", message: message)
    }
    
    public static func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        writeLogEntry(level: "WARN", message: message)
    }
    
    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        writeLogEntry(level: "ERROR", message: message)
    }
    
    public static func fault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
        writeLogEntry(level: "FAULT", message: message)
    }
    
    private static func writeLogEntry(level: String, message: String) {
        guard let url = logFileURL else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level)] \(message)\n"
        
        guard let data = logLine.data(using: .utf8) else { return }
        
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
