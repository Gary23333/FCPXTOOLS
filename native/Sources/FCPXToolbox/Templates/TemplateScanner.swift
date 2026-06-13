import Foundation

/// 扫描用户与系统两处 Motion Templates 根目录，发现所有模板。
/// 显示名解析交给 macOS（`.localizedNameKey`），自动处理 `.localized` 的
/// 两种 strings 格式与 zh_CN 优先级——与 FCP 自身机制一致。
final class TemplateScanner {
    private let fm = FileManager.default
    private var cancelled = false

    /// 各分类的 Motion 模板文档扩展名：
    /// Title=.moti、Effect=.moef、Transition=.motr、Generator=.motn、Composition=.moco。
    /// 字幕分类里偶有 .moef 的特例，因此按集合匹配而非单一扩展名。
    static let templateExtensions: Set<String> = ["moti", "moef", "motr", "motn", "moco"]

    static let userRoot = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/Motion Templates.localized", isDirectory: true)

    static let systemRoot = URL(fileURLWithPath:
        "/Library/Application Support/Final Cut Pro/Templates.localized", isDirectory: true)

    func cancel() { cancelled = true }

    func scan(progress: @escaping (TemplateScanProgress) -> Void,
              itemFound: @escaping (TemplateItem) -> Void = { _ in }) -> TemplateScanResult {
        cancelled = false
        let started = Date()
        var items: [TemplateItem] = []
        var state = TemplateScanProgress()
        var lastEmit = Date.distantPast

        func emit(force: Bool = false) {
            guard force || Date().timeIntervalSince(lastEmit) > 0.15 else { return }
            lastEmit = Date()
            progress(state)
        }

        let roots: [(URL, TemplateRoot)] = [
            (Self.userRoot, .user),
            (Self.systemRoot, .system)
        ]

        for (root, source) in roots {
            guard !cancelled, isDirectory(root) else { continue }
            for category in TemplateCategory.allCases {
                guard !cancelled else { break }
                let categoryDir = root.appendingPathComponent("\(category.rawValue).localized", isDirectory: true)
                guard isDirectory(categoryDir) else { continue }
                walk(categoryDir, category: category, categoryDir: categoryDir, root: source) { item in
                    items.append(item)
                    state.currentPath = item.folderURL.path
                    state.discovered = items.count
                    state.totalBytes += item.bytes
                    itemFound(item)
                    emit()
                }
            }
        }

        emit(force: true)
        return TemplateScanResult(
            items: items.sorted {
                ($0.category.rawValue, $0.group, $0.displayName)
                    < ($1.category.rawValue, $1.group, $1.displayName)
            },
            duration: Date().timeIntervalSince(started)
        )
    }

    /// 递归查找包含 `.moti` 的文件夹；该文件夹即一个模板。
    private func walk(_ dir: URL, category: TemplateCategory, categoryDir: URL, root: TemplateRoot, found: (TemplateItem) -> Void) {
        guard !cancelled else { return }
        let entries = contents(of: dir)

        if let doc = entries.first(where: { Self.templateExtensions.contains($0.pathExtension.lowercased()) }) {
            found(makeItem(folder: dir, moti: doc, category: category, categoryDir: categoryDir, root: root))
            return // 模板文件夹内部不再深挖（Media/ 等是其内容）
        }

        for child in entries where isDirectory(child) && !isSymlink(child) {
            walk(child, category: category, categoryDir: categoryDir, root: root, found: found)
        }
    }

    private func makeItem(folder: URL, moti: URL, category: TemplateCategory, categoryDir: URL, root: TemplateRoot) -> TemplateItem {
        let large = folder.appendingPathComponent("large.png")
        let small = folder.appendingPathComponent("small.png")
        let poster: URL? = fm.fileExists(atPath: large.path) ? large
            : (fm.fileExists(atPath: small.path) ? small : nil)

        let parent = folder.deletingLastPathComponent()
        let group = parent.path == categoryDir.path ? "未分组" : localizedName(parent)
        let measured = measure(folder)

        return TemplateItem(
            id: folder,
            folderName: folder.lastPathComponent,
            displayName: localizedName(folder),
            category: category,
            group: group,
            motiURL: moti,
            posterURL: poster,
            bytes: measured.bytes,
            modifiedAt: measured.modifiedAt,
            root: root
        )
    }

    // MARK: - Helpers

    private func localizedName(_ url: URL) -> String {
        let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? nil
        // localizedName 会带上扩展名后缀处理；去掉 .localized 残留。
        var resolved = name ?? url.lastPathComponent
        if resolved.hasSuffix(".localized") {
            resolved = String(resolved.dropLast(".localized".count))
        }
        return resolved
    }

    private func measure(_ url: URL) -> (bytes: Int64, modifiedAt: Date?) {
        var bytes: Int64 = 0
        var latest: Date?
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return (0, nil)
        }
        for case let f as URL in e {
            let v = try? f.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard v?.isRegularFile == true else { continue }
            bytes += Int64(v?.fileSize ?? 0)
            if let m = v?.contentModificationDate, latest == nil || m > latest! { latest = m }
        }
        return (bytes, latest)
    }

    private func contents(of url: URL) -> [URL] {
        (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}
