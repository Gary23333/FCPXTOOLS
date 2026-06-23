import SwiftUI
import Combine

@MainActor
final class ProcessManagerViewModel: ObservableObject {
    private static let fcpxBundleID = "com.apple.FinalCut"
    private static let appURL = URL(fileURLWithPath: "/Applications/Final Cut Pro.app")

    @Published var isRunning = false
    @Published var pid: pid_t = 0
    @Published var residentBytes: Int64 = 0
    @Published var lastUpdated: Date = Date()
    @Published var statusMessage = "正在监控 Final Cut Pro 进程状态"
    @Published var errorMessage: String?

    private var timer: AnyCancellable?

    init() {
        refresh()
        startTimer()
    }

    /// 启动每 2 秒自动刷新的定时器。
    private func startTimer() {
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
    }

    /// 刷新 FCPX 运行状态与进程信息。
    func refresh() {
        let app = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == Self.fcpxBundleID
        }
        if let app, app.processIdentifier > 0 {
            isRunning = true
            pid = app.processIdentifier
            residentBytes = residentMemoryBytes(for: app.processIdentifier) ?? 0
        } else {
            isRunning = false
            pid = 0
            residentBytes = 0
        }
        lastUpdated = Date()
    }

    /// 启动 Final Cut Pro。
    func launch() {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: Self.appURL, configuration: config) { _, error in
            Task { @MainActor in
                if let error {
                    self.errorMessage = "启动失败：\(error.localizedDescription)"
                } else {
                    self.statusMessage = "已请求启动 Final Cut Pro"
                }
                self.refresh()
            }
        }
    }

    /// 优雅退出 Final Cut Pro。
    func terminate() {
        guard let app = currentApp() else { return }
        app.terminate()
        statusMessage = "已请求退出 Final Cut Pro"
    }

    /// 强制退出 Final Cut Pro。
    func forceTerminate() {
        guard let app = currentApp() else { return }
        app.forceTerminate()
        statusMessage = "已强制退出 Final Cut Pro"
    }

    /// 打开 FCPX 缓存目录以便手动清理，或提示使用清理助手。
    func clearCache() {
        let home = NSHomeDirectory()
        let cacheURL = URL(fileURLWithPath: "\(home)/Library/Caches/Final Cut Pro")
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            NSWorkspace.shared.open(cacheURL)
            statusMessage = "已打开缓存目录，请手动清理，或使用清理助手"
        } else {
            statusMessage = "缓存目录不存在，建议使用清理助手扫描资源库"
        }
    }

    private func currentApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == Self.fcpxBundleID
        }
    }

    /// 通过 proc_pidinfo 读取进程驻留内存（字节）。
    private func residentMemoryBytes(for pid: pid_t) -> Int64? {
        var info = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
        guard size == Int32(MemoryLayout<proc_taskinfo>.size) else { return nil }
        return Int64(info.pti_resident_size)
    }
}

struct ProcessManagerView: View {
    @StateObject private var model = ProcessManagerViewModel()

    var body: some View {
        VStack(spacing: 14) {
            header
            statusCard
            actionsCard
            Spacer()
            statusBar
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .alert("进程操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    // MARK: - 顶部标题

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "activity")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("FCPX 进程管理")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("监控 Final Cut Pro 运行状态，支持启动、退出与强制退出，每 2 秒自动刷新。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - 状态卡片

    private var statusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    statusIndicator
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.isRunning ? "运行中" : "未运行")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(model.isRunning ? Theme.safe : Theme.textSecondary)
                        Text(model.isRunning ? "Final Cut Pro 正在运行" : "Final Cut Pro 未启动")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 24) {
                    statPair("进程 PID", model.isRunning ? "\(model.pid)" : "—", Theme.textPrimary)
                    statPair("内存占用", model.isRunning ? DisplayFormat.byteString(model.residentBytes) : "—", Theme.textPrimary)
                    statPair("刷新时间", DisplayFormat.dateString(model.lastUpdated), Theme.textSecondary)
                }
            }
            .padding(16)
        }
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill((model.isRunning ? Theme.safe : Theme.textSecondary).opacity(0.16))
                .frame(width: 48, height: 48)
            Image(systemName: model.isRunning ? "checkmark.circle.fill" : "moon.zzz")
                .font(.system(size: 24))
                .foregroundStyle(model.isRunning ? Theme.safe : Theme.textSecondary)
        }
    }

    private func statPair(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - 操作卡片

    private var actionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("进程操作")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 10) {
                    actionButton("启动 Final Cut Pro", systemImage: "play.fill",
                                 color: Theme.safe, isEnabled: !model.isRunning) {
                        model.launch()
                    }
                    actionButton("退出 Final Cut Pro", systemImage: "xmark.circle",
                                 color: Theme.warning, isEnabled: model.isRunning) {
                        model.terminate()
                    }
                    actionButton("强制退出", systemImage: "exclamationmark.triangle",
                                 color: Theme.danger, isEnabled: model.isRunning) {
                        model.forceTerminate()
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    actionButton("清除渲染缓存", systemImage: "trash",
                                 color: Theme.accent, isEnabled: true) {
                        model.clearCache()
                    }
                    Spacer()
                    Button {
                        model.refresh()
                    } label: {
                        Label("立即刷新", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.panel)
                            .foregroundStyle(Theme.accent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func actionButton(_ title: String, systemImage: String, color: Color, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .opacity(isEnabled ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
            Text(model.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("每 2 秒自动刷新")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
