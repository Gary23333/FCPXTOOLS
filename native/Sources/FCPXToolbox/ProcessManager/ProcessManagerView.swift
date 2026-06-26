import SwiftUI
import Combine
import Darwin

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
    @ObservedObject var model: ProcessManagerViewModel

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                NeoSectionHeader(
                    systemImage: "activity",
                    title: "FCPX 进程管理"
                )

                NeoButton(
                    title: "",
                    systemImage: "arrow.clockwise",
                    style: .ghost,
                    size: .sm
                ) {
                    model.refresh()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                HStack {
                    Text("运行状态:")
                        .foregroundStyle(Theme.textSecondary)
                    Text(model.isRunning ? "运行中" : "未运行")
                        .fontWeight(.bold)
                        .foregroundStyle(model.isRunning ? Theme.safe : Theme.textSecondary)
                    Spacer()
                    if model.isRunning {
                        Text("PID: \(model.pid)")
                            .font(FT.data())
                            .padding(.horizontal, Spacing.xxxs)
                            .padding(.vertical, 1)
                            .background(Theme.background)
                    }
                }

                if model.isRunning {
                    HStack {
                        Text("内存占用:")
                            .foregroundStyle(Theme.textSecondary)
                        Text(DisplayFormat.byteString(model.residentBytes))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("更新时间:")
                            .foregroundStyle(Theme.textSecondary)
                        Text(DisplayFormat.dateString(model.lastUpdated))
                    }
                }
            }
            .font(FT.label())

            Divider()

            VStack(spacing: Spacing.xxs) {
                if !model.isRunning {
                    NeoButton(
                        title: "启动 Final Cut Pro",
                        systemImage: "play.fill",
                        style: .primary,
                        size: .md
                    ) {
                        model.launch()
                    }
                } else {
                    HStack(spacing: Spacing.xxs) {
                        NeoButton(
                            title: "退出",
                            systemImage: "xmark.circle",
                            style: .secondary,
                            size: .md
                        ) {
                            model.terminate()
                        }

                        NeoButton(
                            title: "强制退出",
                            systemImage: "exclamationmark.triangle",
                            style: .destructive,
                            size: .md
                        ) {
                            model.forceTerminate()
                        }
                    }
                }

                NeoButton(
                    title: "清除渲染缓存",
                    systemImage: "trash",
                    style: .secondary,
                    size: .md
                ) {
                    model.clearCache()
                }
            }

            Text(model.statusMessage)
                .font(FT.label(10))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.xxxs)
        }
        .padding(Spacing.sm)
        .background(Theme.panel)
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
}
