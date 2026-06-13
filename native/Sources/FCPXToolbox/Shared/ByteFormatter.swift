import Foundation

enum DisplayFormat {
    static let bytes: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func byteString(_ value: Int64) -> String {
        bytes.string(fromByteCount: value)
    }

    static func dateString(_ value: Date?) -> String {
        guard let value else { return "-" }
        return date.string(from: value)
    }
}
