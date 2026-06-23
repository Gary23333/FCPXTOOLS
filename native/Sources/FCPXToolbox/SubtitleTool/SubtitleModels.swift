import Foundation

/// SRT 字幕条目
struct SRTEntry: Identifiable, Hashable {
    let id = UUID()
    var index: Int
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String

    /// 格式化时间戳为 SRT 格式：HH:MM:SS,mmm
    func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(Int(time))) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    var startTimeString: String { formatTime(startTime) }
    var endTimeString: String { formatTime(endTime) }

    /// 转为 SRT 文本块
    func toSRTBlock() -> String {
        "\(index)\n\(startTimeString) --> \(endTimeString)\n\(text)\n"
    }
}

/// ASR 转录状态
enum TranscriptionStatus: String {
    case idle = "就绪"
    case preparing = "准备中"
    case transcribing = "转录中"
    case completed = "已完成"
    case failed = "失败"
}

/// 支持的语言
enum SubtitleLanguage: String, CaseIterable, Identifiable {
    case zhCN = "zh-CN"
    case zhTW = "zh-TW"
    case enUS = "en-US"
    case jaJP = "ja-JP"
    case koKR = "ko-KR"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .zhCN: return "简体中文"
        case .zhTW: return "繁体中文"
        case .enUS: return "英语 (美国)"
        case .jaJP: return "日语"
        case .koKR: return "韩语"
        }
    }
}
