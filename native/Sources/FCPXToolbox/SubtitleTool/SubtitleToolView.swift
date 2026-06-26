import SwiftUI
import Speech
import AVFoundation
import UniformTypeIdentifiers

// MARK: - ViewModel

@MainActor
final class SubtitleToolViewModel: ObservableObject {
    @Published var audioFileURL: URL?
    @Published var entries: [SRTEntry] = []
    @Published var status: TranscriptionStatus = .idle
    @Published var statusText: String = "选择音频或视频文件开始"
    @Published var progressValue: Double = 0
    @Published var selectedLanguage: SubtitleLanguage = .zhCN
    @Published var errorMessage: String?
    @Published var isPlaying: Bool = false
    @Published var currentEntryID: SRTEntry.ID?

    @Published private(set) var fileDuration: TimeInterval = 0
    @Published private(set) var fileSize: Int64 = 0

    private var recognitionTask: SFSpeechRecognitionTask?

    var isBusy: Bool { status == .transcribing || status == .preparing }
    var canTranscribe: Bool { audioFileURL != nil && !isBusy }
    var canExport: Bool { !entries.isEmpty && !isBusy }

    var durationString: String {
        guard fileDuration > 0 else { return "-" }
        let total = Int(fileDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - 文件选择

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie, .mp3, .wav, UTType(filenameExtension: "m4a") ?? .audio, .audio]
        if panel.runModal() == .OK, let url = panel.url {
            audioFileURL = url
            entries = []
            currentEntryID = nil
            status = .idle
            statusText = "已选择文件，点击「开始转录」"
            progressValue = 0
            errorMessage = nil
            loadFileInfo(url)
        }
    }

    private func loadFileInfo(_ url: URL) {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        } else {
            fileSize = 0
        }
        fileDuration = 0
        Task {
            let asset = AVAsset(url: url)
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    self.fileDuration = CMTimeGetSeconds(duration)
                }
            } catch {
                await MainActor.run {
                    self.fileDuration = 0
                }
            }
        }
    }

    // MARK: - 语音转录

    func startTranscription() {
        guard let url = audioFileURL, !isBusy else { return }
        entries = []
        currentEntryID = nil
        errorMessage = nil
        progressValue = 0
        status = .preparing
        statusText = "正在准备语音识别…"

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                guard let self = self else { return }
                switch authStatus {
                case .authorized:
                    self.loadDurationAndTranscribe(url: url)
                case .denied:
                    self.status = .failed
                    self.statusText = "语音识别权限被拒绝"
                    self.errorMessage = "请在「系统设置 > 隐私与安全性 > 语音识别」中允许本应用"
                case .restricted:
                    self.status = .failed
                    self.statusText = "语音识别受限"
                    self.errorMessage = "此设备不支持语音识别"
                case .notDetermined:
                    self.status = .failed
                    self.statusText = "语音识别未授权"
                    self.errorMessage = "无法获取语音识别权限"
                @unknown default:
                    self.status = .failed
                    self.statusText = "未知错误"
                    self.errorMessage = "发生未知错误"
                }
            }
        }
    }

    private func loadDurationAndTranscribe(url: URL) {
        status = .preparing
        statusText = "正在读取文件信息…"

        Task {
            let asset = AVAsset(url: url)
            do {
                let cmDuration = try await asset.load(.duration)
                let duration = CMTimeGetSeconds(cmDuration)
                await MainActor.run {
                    self.fileDuration = duration
                    self.performTranscription(url: url, duration: duration)
                }
            } catch {
                await MainActor.run {
                    self.status = .failed
                    self.statusText = "读取文件时长失败"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func performTranscription(url: URL, duration: TimeInterval) {
        let locale = Locale(identifier: selectedLanguage.rawValue)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            status = .failed
            statusText = "不支持的语言"
            errorMessage = "无法创建「\(selectedLanguage.displayName)」的语音识别器"
            return
        }

        status = .transcribing
        statusText = "正在转录…"
        progressValue = 0.05

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.status = .failed
                    self.statusText = "转录失败"
                    self.errorMessage = error.localizedDescription
                    self.progressValue = 0
                    self.recognitionTask = nil
                }
                return
            }

            guard let result = result else { return }

            // 根据最后一段的时间戳更新进度
            if let lastSegment = result.bestTranscription.segments.last, duration > 0 {
                let progress = min(0.95, lastSegment.timestamp / duration)
                Task { @MainActor in
                    self.progressValue = progress
                }
            }

            if result.isFinal {
                let segments = result.bestTranscription.segments.map { seg in
                    (timestamp: seg.timestamp, duration: seg.duration, text: seg.substring)
                }
                Task { @MainActor in
                    self.buildEntries(from: segments, totalDuration: duration)
                    self.recognitionTask = nil
                }
            }
        }
    }

    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        status = .idle
        statusText = "已取消转录"
        progressValue = 0
    }

    /// 将识别片段按时间戳和自然停顿分段，生成 SRT 条目
    private func buildEntries(
        from segments: [(timestamp: TimeInterval, duration: TimeInterval, text: String)],
        totalDuration: TimeInterval
    ) {
        guard !segments.isEmpty else {
            status = .completed
            statusText = "未识别到语音内容"
            progressValue = 1.0
            return
        }

        let hasTimestamps = segments.contains { $0.timestamp > 0 }
        var newEntries: [SRTEntry] = []

        if hasTimestamps {
            // 按时间戳和自然停顿分段，每段约 3-5 秒
            let maxSegmentDuration: TimeInterval = 4.0
            let pauseThreshold: TimeInterval = 0.5

            var currentText: [String] = []
            var entryStart = segments[0].timestamp
            var entryEnd = segments[0].timestamp + segments[0].duration

            for segment in segments {
                let segStart = segment.timestamp
                let segEnd = segment.timestamp + segment.duration
                let gap = segStart - entryEnd

                if !currentText.isEmpty &&
                   (gap > pauseThreshold || (segEnd - entryStart) > maxSegmentDuration) {
                    newEntries.append(SRTEntry(
                        index: newEntries.count + 1,
                        startTime: entryStart,
                        endTime: entryEnd,
                        text: currentText.joined()
                    ))
                    currentText = []
                    entryStart = segStart
                }
                currentText.append(segment.text)
                entryEnd = segEnd
            }

            if !currentText.isEmpty {
                newEntries.append(SRTEntry(
                    index: newEntries.count + 1,
                    startTime: entryStart,
                    endTime: entryEnd,
                    text: currentText.joined()
                ))
            }
        } else {
            // 时间戳不可用，按固定时长分段
            let segmentDuration: TimeInterval = 4.0
            let entryCount = max(1, Int(totalDuration / segmentDuration))
            let perEntry = max(1, segments.count / entryCount)

            var startTime: TimeInterval = 0
            var currentText: [String] = []
            var count = 0

            for segment in segments {
                currentText.append(segment.text)
                count += 1
                if count >= perEntry {
                    let endTime = min(startTime + segmentDuration, totalDuration)
                    newEntries.append(SRTEntry(
                        index: newEntries.count + 1,
                        startTime: startTime,
                        endTime: endTime,
                        text: currentText.joined()
                    ))
                    startTime = endTime
                    currentText = []
                    count = 0
                }
            }

            if !currentText.isEmpty {
                let endTime = min(startTime + segmentDuration, totalDuration)
                newEntries.append(SRTEntry(
                    index: newEntries.count + 1,
                    startTime: startTime,
                    endTime: endTime,
                    text: currentText.joined()
                ))
            }
        }

        entries = newEntries
        status = .completed
        statusText = "转录完成，共 \(newEntries.count) 条字幕"
        progressValue = 1.0
    }

    // MARK: - SRT 导入

    func importSRT(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let parsed = parseSRT(content)
            if parsed.isEmpty {
                status = .failed
                statusText = "未解析到有效字幕"
                errorMessage = "SRT 文件为空或格式不正确"
                return
            }
            entries = parsed
            reindex()
            status = .completed
            statusText = "已导入 \(parsed.count) 条字幕"
            progressValue = 1.0
            errorMessage = nil
        } catch {
            status = .failed
            statusText = "导入失败"
            errorMessage = error.localizedDescription
        }
    }

    private func parseSRT(_ content: String) -> [SRTEntry] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")

        var result: [SRTEntry] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard lines.count >= 2 else { continue }

            var lineIndex = 0
            if Int(lines[0].trimmingCharacters(in: .whitespaces)) != nil {
                lineIndex = 1
            }

            guard lineIndex < lines.count else { continue }
            let timeLine = lines[lineIndex]
            let times = timeLine.components(separatedBy: "-->")
            guard times.count == 2 else { continue }

            let start = parseSRTTime(times[0])
            let end = parseSRTTime(times[1])
            let text = (lineIndex + 1 < lines.count)
                ? lines[(lineIndex + 1)...].joined(separator: "\n")
                : ""

            result.append(SRTEntry(
                index: result.count + 1,
                startTime: start,
                endTime: end,
                text: text
            ))
        }
        return result
    }

    private func parseSRTTime(_ time: String) -> TimeInterval {
        let cleaned = time.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: ",")
        let parts = cleaned.components(separatedBy: ":")
        guard parts.count == 3 else { return 0 }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let secondParts = parts[2].components(separatedBy: ",")
        let seconds = Double(secondParts[0]) ?? 0
        let millis = secondParts.count > 1 ? (Double(secondParts[1]) ?? 0) / 1000 : 0

        return hours * 3600 + minutes * 60 + seconds + millis
    }

    // MARK: - SRT 导出

    func exportSRT() {
        guard !entries.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "subtitle.srt"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            let content = entries.map { $0.toSRTBlock() }.joined(separator: "\n")
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                statusText = "已导出到 \(url.lastPathComponent)"
            } catch {
                status = .failed
                statusText = "导出失败"
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - 条目编辑

    func updateEntry(_ entry: SRTEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].text = entry.text
        }
    }

    func deleteEntry(_ entry: SRTEntry) {
        entries.removeAll { $0.id == entry.id }
        reindex()
    }

    func addEntry(after entry: SRTEntry) {
        let newEntry = SRTEntry(
            index: 0,
            startTime: entry.endTime,
            endTime: entry.endTime + 3,
            text: "新字幕"
        )
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.insert(newEntry, at: idx + 1)
        } else {
            entries.append(newEntry)
        }
        reindex()
    }

    func reindex() {
        for i in entries.indices {
            entries[i].index = i + 1
        }
    }

    // MARK: - 播放

    func togglePlayback() {
        isPlaying.toggle()
    }
}

// MARK: - View

struct SubtitleToolView: View {
    @StateObject private var model = SubtitleToolViewModel()

    var body: some View {
        VStack(spacing: Spacing.xs) {
            toolbar
            content
            statusBar
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .alert("出错了", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: Spacing.xs) {
            NeoSectionHeader(
                systemImage: "captions.bubble",
                title: "快速字幕",
                subtitle: model.audioFileURL?.lastPathComponent ?? "选择音频或视频文件开始转录"
            )
            languageMenu
            NeoButton(
                title: "选择文件",
                systemImage: "folder.badge.plus",
                style: .secondary,
                size: .sm,
                isEnabled: !model.isBusy
            ) {
                model.chooseFile()
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(SubtitleLanguage.allCases) { lang in
                Button(lang.displayName) {
                    model.selectedLanguage = lang
                }
            }
        } label: {
            HStack(spacing: Spacing.xxxs) {
                Text("语言")
                    .foregroundStyle(Theme.textSecondary)
                Text(model.selectedLanguage.displayName)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .font(FontFamily.caption(12, weight: .medium))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxxs)
            .background(Theme.panel)
            .overlay(
                Rectangle()
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 主区

    private var content: some View {
        HStack(spacing: Spacing.sm) {
            leftPanel
                .frame(width: 280)
            rightPanel
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var leftPanel: some View {
        VStack(spacing: Spacing.sm) {
            fileInfoCard
            actionCard
            Spacer(minLength: 0)
        }
    }

    private var fileInfoCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("文件信息")
                    .font(FontFamily.heading(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let url = model.audioFileURL {
                    infoRow("文件名", url.lastPathComponent, valueIsData: true)
                    infoRow("时长", model.durationString, valueIsData: true)
                    infoRow("大小", DisplayFormat.byteString(model.fileSize), valueIsData: true)
                    infoRow("语言", model.selectedLanguage.displayName)
                } else {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "waveform")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("尚未选择文件")
                            .font(FontFamily.caption(12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.xxs)
                }
            }
            .padding(Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoRow(_ title: String, _ value: String, valueIsData: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(FontFamily.caption(12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(valueIsData ? FT.data(12, weight: .medium) : FontFamily.bodyText(12, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var actionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("操作")
                    .font(FontFamily.heading(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                NeoButton(
                    title: "开始转录",
                    systemImage: "waveform",
                    style: .primary,
                    size: .md,
                    isEnabled: model.canTranscribe
                ) {
                    model.startTranscription()
                }
                if model.isBusy {
                    NeoButton(
                        title: "取消",
                        systemImage: "stop.circle",
                        style: .ghost,
                        size: .md,
                        isEnabled: true
                    ) {
                        model.cancelTranscription()
                    }
                }
                NeoButton(
                    title: "导入 SRT",
                    systemImage: "square.and.arrow.down",
                    style: .secondary,
                    size: .md,
                    isEnabled: !model.isBusy
                ) {
                    showImportPanel()
                }
                NeoButton(
                    title: "导出 SRT",
                    systemImage: "square.and.arrow.up",
                    style: .secondary,
                    size: .md,
                    isEnabled: model.canExport
                ) {
                    model.exportSRT()
                }
            }
            .padding(Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 字幕列表

    private var rightPanel: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text("字幕条目")
                        .font(FontFamily.heading(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("共 \(model.entries.count) 条")
                        .font(FontFamily.caption(12))
                        .foregroundStyle(Theme.textSecondary)
                }
                if model.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.xxs) {
                            ForEach(model.entries) { entry in
                                entryRow(entry)
                            }
                        }
                        .padding(Spacing.xxxs)
                    }
                }
            }
            .padding(Spacing.xs)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xxs) {
            Spacer()
            Image(systemName: "captions.bubble")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Text("暂无字幕")
                .foregroundStyle(Theme.textSecondary)
            Text("选择文件后点击「开始转录」，或导入现有 SRT 文件")
                .font(FontFamily.caption(12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func entryRow(_ entry: SRTEntry) -> some View {
        let textBinding = Binding<String>(
            get: { entry.text },
            set: { newValue in
                var updated = entry
                updated.text = newValue
                model.updateEntry(updated)
            }
        )
        let isSelected = model.currentEntryID == entry.id
        return VStack(alignment: .leading, spacing: Spacing.xxxs) {
            HStack(spacing: Spacing.xxs) {
                Text("\(entry.index)")
                    .font(FT.data(13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, alignment: .center)
                Text("\(entry.startTimeString) --> \(entry.endTimeString)")
                    .font(FT.data(11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    model.addEntry(after: entry)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                Button {
                    model.deleteEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
            TextEditor(text: textBinding)
                .font(FontFamily.bodyText(13))
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .frame(height: 60)
                .padding(Spacing.xxxs)
                .overlay(
                    Rectangle()
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .padding(Spacing.sm)
        .background(Theme.background)
        .overlay(
            Rectangle()
                .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            model.currentEntryID = entry.id
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: Spacing.xxxs) {
            NeoProgress(value: model.progressValue)
            HStack {
                Text(model.statusText)
                    .font(FontFamily.caption(12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(model.status.rawValue)
                    .font(FT.data(12, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .completed: return Theme.safe
        case .failed: return Theme.danger
        case .transcribing, .preparing: return Theme.accent
        case .idle: return Theme.textSecondary
        }
    }

    // MARK: - 导入面板

    private func showImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            model.importSRT(url: url)
        }
    }

    // MARK: - 绑定

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
