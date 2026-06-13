import Foundation

/// 共享文件操作：统一走废纸篓、可逆移动，绝不永久删除。
/// 清理域与模板域都复用此处的安全范式。
enum FileMover {
    /// 移到废纸篓（可在废纸篓找回），返回废纸篓内的新位置。
    @discardableResult
    static func trash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }

    /// 移动文件/目录，必要时创建目标父目录。用于「停用区」可逆移动。
    static func move(_ source: URL, to destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }
}
