import Foundation

/// FCPX 工具箱统一错误枚举。
public enum FCPXToolboxError: Error, LocalizedError {
    case permissionDenied(path: String)
    case fileNotFound(path: String)
    case directoryCreationFailed(path: String, underlyingError: Error)
    case fileOperationFailed(from: String, to: String, underlyingError: Error)
    
    // Plist / Serialization
    case plistReadFailed(path: String, underlyingError: Error)
    case plistWriteFailed(path: String, underlyingError: Error)
    case serializationError(message: String)
    
    // ASR 字幕转录
    case speechRecognitionNotAuthorized
    case speechRecognitionFailed(message: String)
    case audioTrackExtractionFailed
    
    // 进程控制
    case processTerminationFailed(pid: Int32, message: String)
    
    // 偏好设置
    case preferenceKeyNotFound(key: String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return String(localized: "权限拒绝：无法访问路径 \"\(path)\"。请确保已授予「完全磁盘访问权限」。", comment: "Permission denied error description")
        case .fileNotFound(let path):
            return String(localized: "文件未找到：找不到指定路径的文件 \"\(path)\"。", comment: "File not found error description")
        case .directoryCreationFailed(let path, let err):
            return String(localized: "创建目录失败：路径 \"\(path)\"，原因：\(err.localizedDescription)", comment: "Directory creation failed error description")
        case .fileOperationFailed(let from, let to, let err):
            return String(localized: "文件操作失败：从 \"\(from)\" 移动/复制到 \"\(to)\" 失败。原因：\(err.localizedDescription)", comment: "File operation failed error description")
        case .plistReadFailed(let path, let err):
            return String(localized: "解析配置文件失败：读取 plist \"\(path)\" 发生错误：\(err.localizedDescription)", comment: "Plist read error description")
        case .plistWriteFailed(let path, let err):
            return String(localized: "写入配置文件失败：写入 plist \"\(path)\" 发生错误：\(err.localizedDescription)", comment: "Plist write error description")
        case .serializationError(let msg):
            return String(localized: "序列化错误：\(msg)", comment: "Serialization error description")
        case .speechRecognitionNotAuthorized:
            return String(localized: "语音识别授权失败：请在系统设置中允许使用麦克风和语音识别功能。", comment: "Speech recognition not authorized description")
        case .speechRecognitionFailed(let msg):
            return String(localized: "语音转录失败：\(msg)", comment: "Speech recognition failed description")
        case .audioTrackExtractionFailed:
            return String(localized: "音频提取失败：无法从所选视频文件中提取音频轨道。", comment: "Audio track extraction failed description")
        case .processTerminationFailed(let pid, let msg):
            return String(localized: "结束进程失败：进程 PID \(pid)，原因：\(msg)", comment: "Process termination failed description")
        case .preferenceKeyNotFound(let key):
            return String(localized: "找不到偏好键值：\"\(key)\"。", comment: "Preference key not found description")
        }
    }
}
