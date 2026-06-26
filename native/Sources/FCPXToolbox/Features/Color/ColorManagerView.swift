import SwiftUI
import CoreImage
import AppKit
import UniformTypeIdentifiers

/// 色彩与 LUT 管理器视图。
struct ColorManagerView: View {
    @State private var items: [ColorItem] = []
    @State private var searchText = ""
    @State private var selectedType: ColorTypeFilter = .all
    @State private var selectedItemID: URL?
    @State private var scanning = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var pendingDeleteItem: ColorItem?

    // LUT Preview States
    @State private var defaultPreviewImage = ColorManagerView.generateDefaultPreviewImage()
    @State private var customImage: NSImage? = nil
    @State private var previewImage: NSImage? = nil
    @State private var isProcessingPreview = false
    @State private var previewMode: PreviewMode = .after

    enum PreviewMode {
        case before, after
    }

    private let scanner = ColorScanner()

    enum ColorTypeFilter: String, CaseIterable, Identifiable {
        case all = "全部类型"
        case lut = "3D LUT (.cube)"
        case colorPreset = "颜色预置"

        var id: String { rawValue }
    }

    var filteredItems: [ColorItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.displayName.localizedCaseInsensitiveContains(searchText) ||
                item.name.localizedCaseInsensitiveContains(searchText)

            let matchesType: Bool
            switch selectedType {
            case .all: matchesType = true
            case .lut: matchesType = item.type == .lut
            case .colorPreset: matchesType = item.type == .colorPreset
            }

            return matchesSearch && matchesType
        }
    }

    var selectedItem: ColorItem? {
        items.first { $0.url == selectedItemID }
    }

    var body: some View {
        HSplitView {
            // 左侧：列表
            VStack(spacing: 0) {
                // 工具栏
                HStack(spacing: Spacing.xs) {
                    // 搜索框
                    NeoInput(placeholder: "搜索 LUT 或预置...", text: $searchText, isSearch: true)

                    // 类型过滤
                    Picker("类型", selection: $selectedType) {
                        ForEach(ColorTypeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)

                    NeoButton(title: "", systemImage: "arrow.clockwise", style: .ghost, size: .sm) {
                        runScan()
                    }
                }
                .padding()

                Divider()

                if scanning {
                    VStack(spacing: Spacing.sm) {
                        NeoProgress(value: 0.5)
                        Text("正在扫描色彩资产...")
                            .font(FontFamily.bodyText(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("未发现符合条件的 LUT 或预置")
                            .font(FontFamily.bodyText(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedItemID) {
                        ForEach(filteredItems) { item in
                            HStack {
                                Image(systemName: item.type == .lut ? "square.stack.3d.down.right.fill" : "slider.horizontal.below.rectangle")
                                    .foregroundColor(Theme.accent)
                                    .font(.system(size: 13))

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(item.displayName)
                                        .font(FontFamily.bodyText(13, weight: .medium))
                                    Text(item.name)
                                        .font(FontFamily.caption(11))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()

                                Text(DisplayFormat.byteString(item.sizeBytes))
                                    .font(FT.label())
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .tag(item.url)
                            .padding(.vertical, Spacing.xxxs)
                            .contextMenu {
                                Button("移至废纸篓", role: .destructive) {
                                    confirmDelete(item)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 450, idealWidth: 600)

            // 右侧：详情面板
            if let item = selectedItem {
                detailPanel(for: item)
                    .frame(width: 340)
                    .background(Theme.panel)
            } else {
                VStack {
                    Text("请选择色彩项目以查看详情")
                        .font(FontFamily.bodyText(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 340)
                .frame(maxHeight: .infinity)
                .background(Theme.panel)
            }
        }
        .background(Theme.background)
        .onAppear {
            runScan()
        }
        .onChange(of: selectedItemID) {
            updatePreview()
        }
        .onChange(of: customImage) {
            updatePreview()
        }
        .alert("确定要删除吗？", isPresented: $showingDeleteAlert, presenting: pendingDeleteItem) { item in
            Button("删除", role: .destructive) {
                performDelete(item)
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("将安全地把「\(item.displayName)」移至系统废纸篓。")
        }
    }

    // MARK: - 详情视图

    private func detailPanel(for item: ColorItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: item.type == .lut ? "cube.transparent.fill" : "paintpalette.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.accent)

                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(item.displayName)
                            .font(FontFamily.heading(18, weight: .bold))
                            .lineLimit(1)
                        NeoBadge(
                            text: item.type.rawValue,
                            style: .accent
                        )
                    }
                }

                Divider()

                Group {
                    infoRow(label: "文件大小", value: DisplayFormat.byteString(item.sizeBytes))
                    if let date = item.modifiedAt {
                        infoRow(label: "修改时间", value: DisplayFormat.dateString(date))
                    }
                }

                // Color LUT Preview Enhancement
                if item.type == .lut {
                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack {
                            Text("效果预览")
                                .font(FontFamily.heading(18, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            Spacer()

                            if customImage != nil {
                                NeoButton(title: "重置", style: .ghost, size: .sm) {
                                    customImage = nil
                                }
                            }

                            NeoButton(title: "上传图片", systemImage: "square.and.arrow.up", style: .ghost, size: .sm) {
                                chooseCustomImage()
                            }
                        }

                        let currentBaseImage = customImage ?? defaultPreviewImage

                        ZStack {
                            let displayImage = (previewMode == .after ? previewImage : nil) ?? currentBaseImage

                            Image(nsImage: displayImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 180)
                                .overlay(
                                    Rectangle()
                                        .stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
                                )

                            if isProcessingPreview {
                                NeoProgress(value: 0.5)
                                    .padding()
                                    .background(Color.black.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.05))

                        // Mode Selector (Before / After)
                        Picker("预览模式", selection: $previewMode) {
                            Text("原图 (Before)").tag(PreviewMode.before)
                            Text("LUT效果 (After)").tag(PreviewMode.after)
                        }
                        .pickerStyle(.segmented)
                        .disabled(previewImage == nil)

                        if previewImage == nil && !isProcessingPreview {
                            Text("仅支持 3D LUT (.cube) 格式的预览")
                                .font(FontFamily.caption(11))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text("文件路径")
                        .font(FontFamily.caption(11))
                        .foregroundStyle(Theme.textSecondary)
                    Text(item.url.path)
                        .font(FT.data(13))
                        .textSelection(.enabled)
                }

                Spacer()

                NeoButton(
                    title: "移至废纸篓",
                    style: .destructive,
                    size: .md
                ) {
                    confirmDelete(item)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FontFamily.bodyText(13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(FT.data())
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - 逻辑

    private func runScan() {
        scanning = true
        errorMessage = nil
        Task {
            let result = scanner.scan()
            await MainActor.run {
                self.items = result
                self.scanning = false
            }
        }
    }

    private func confirmDelete(_ item: ColorItem) {
        pendingDeleteItem = item
        showingDeleteAlert = true
    }

    private func performDelete(_ item: ColorItem) {
        do {
            try scanner.deleteItem(item)
            if let idx = items.firstIndex(where: { $0.url == item.url }) {
                items.remove(at: idx)
            }
            if selectedItemID == item.url {
                selectedItemID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chooseCustomImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "上传图片"
        panel.message = "选择一张图片以预览 LUT 效果"
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                self.customImage = image
            }
        }
    }

    private func updatePreview() {
        guard let item = selectedItem, item.type == .lut else {
            previewImage = nil
            return
        }

        let baseImage = customImage ?? defaultPreviewImage
        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            previewImage = nil
            return
        }

        isProcessingPreview = true
        let lutURL = item.url
        let imageSize = baseImage.size

        Task.detached(priority: .userInitiated) {
            let applied = Self.applyLUT(cgImage: cgImage, imageSize: imageSize, lutURL: lutURL)
            await MainActor.run {
                self.previewImage = applied
                self.isProcessingPreview = false
            }
        }
    }

    private nonisolated static func applyLUT(cgImage: CGImage, imageSize: CGSize, lutURL: URL) -> NSImage? {
        guard let content = try? String(contentsOf: lutURL, encoding: .utf8) else { return nil }

        var size: Int = 0
        var cubeData: [Float] = []

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split { $0.isWhitespace }.map(String.init)
            if parts.isEmpty { continue }

            if parts[0] == "LUT_3D_SIZE" {
                if parts.count > 1, let s = Int(parts[1]) {
                    size = s
                }
            } else if parts[0] == "LUT_1D_SIZE" {
                return nil
            } else if let r = Float(parts[0]), parts.count >= 3,
                      let g = Float(parts[1]),
                      let b = Float(parts[2]) {
                cubeData.append(r)
                cubeData.append(g)
                cubeData.append(b)
                cubeData.append(1.0)
            }
        }

        guard size > 0, cubeData.count == size * size * size * 4 else {
            return nil
        }

        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
        let ciImage = CIImage(cgImage: cgImage)

        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(size, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        filter?.setValue(ciImage, forKey: "inputImage")

        guard let outputImage = filter?.outputImage else { return nil }

        let context = CIContext(options: nil)
        guard let outCGImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        return NSImage(cgImage: outCGImage, size: imageSize)
    }

    static func generateDefaultPreviewImage() -> NSImage {
        let size = CGSize(width: 800, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let skyColors = [
            CGColor(red: 0.1, green: 0.2, blue: 0.45, alpha: 1.0),
            CGColor(red: 0.85, green: 0.4, blue: 0.4, alpha: 1.0),
            CGColor(red: 0.95, green: 0.7, blue: 0.3, alpha: 1.0)
        ] as CFArray
        let skyLocations: [CGFloat] = [0.0, 0.6, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: skyColors, locations: skyLocations) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 600), end: CGPoint(x: 0, y: 150), options: [])
        }

        let sunColors = [
            CGColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 1.0),
            CGColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.8),
            CGColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 0.0)
        ] as CFArray
        if let sunGradient = CGGradient(colorsSpace: colorSpace, colors: sunColors, locations: [0.0, 0.2, 1.0]) {
            context.drawRadialGradient(sunGradient, startCenter: CGPoint(x: 400, y: 220), startRadius: 0, endCenter: CGPoint(x: 400, y: 220), endRadius: 100, options: [])
        }

        context.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0))
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 120))
        context.addQuadCurve(to: CGPoint(x: 450, y: 180), control: CGPoint(x: 200, y: 100))
        context.addQuadCurve(to: CGPoint(x: 800, y: 120), control: CGPoint(x: 650, y: 220))
        context.addLine(to: CGPoint(x: 800, y: 80))
        context.addLine(to: CGPoint(x: 0, y: 80))
        context.closePath()
        context.fillPath()

        let barHeight: CGFloat = 80
        let colors = [
            CGColor(red: 1, green: 0, blue: 0, alpha: 1),
            CGColor(red: 0, green: 1, blue: 0, alpha: 1),
            CGColor(red: 0, green: 0, blue: 1, alpha: 1),
            CGColor(red: 0, green: 1, blue: 1, alpha: 1),
            CGColor(red: 1, green: 0, blue: 1, alpha: 1),
            CGColor(red: 1, green: 1, blue: 0, alpha: 1),
            CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
            CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        ]

        let segmentWidth = 800.0 / CGFloat(colors.count)
        for (i, color) in colors.enumerated() {
            context.setFillColor(color)
            context.fill(CGRect(x: CGFloat(i) * segmentWidth, y: 0, width: segmentWidth, height: barHeight))
        }

        let skinColors = [
            CGColor(red: 0.9, green: 0.72, blue: 0.62, alpha: 1.0),
            CGColor(red: 0.76, green: 0.57, blue: 0.46, alpha: 1.0),
            CGColor(red: 0.45, green: 0.32, blue: 0.24, alpha: 1.0)
        ]
        let skinWidth: CGFloat = 60
        let skinHeight: CGFloat = 40
        for (i, color) in skinColors.enumerated() {
            context.setFillColor(color)
            context.fill(CGRect(x: 310 + CGFloat(i) * (skinWidth + 10), y: barHeight - 20, width: skinWidth, height: skinHeight))
        }

        image.unlockFocus()
        return image
    }
}
