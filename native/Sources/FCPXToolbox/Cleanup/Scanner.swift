import Foundation

final class FCPXScanner {
    private let fm = FileManager.default
    private var cancelled = false

    func cancel() {
        cancelled = true
    }

    func scan(root: URL, progress: @escaping (ScanProgress) -> Void, projectFound: @escaping (ResourceItem) -> Void) -> ScanResult {
        cancelled = false
        let started = Date()
        var state = ScanProgress(currentPath: root.path)
        var projects: [ResourceItem] = []
        var issues: [ScanIssue] = []
        var lastProgress = Date.distantPast

        func emit(force: Bool = false) {
            guard force || Date().timeIntervalSince(lastProgress) > 0.18 else { return }
            lastProgress = Date()
            progress(state)
        }

        func scanDirectory(_ url: URL, parentProject: URL?) {
            guard !cancelled else { return }
            state.currentPath = url.path
            state.scannedDirectories += 1
            emit()

            let entries = contents(of: url) { issues.append($0) }
            let ext = url.pathExtension.lowercased()
            let isLibrary = ext == "fcpbundle"
            let isLegacyProject = ext == "fcpproject"
            let hasEvent = entries.contains { $0.lastPathComponent == "CurrentVersion.fcpevent" }
            let projectRoot = (isLibrary || isLegacyProject) ? url : parentProject

            if isLibrary || isLegacyProject || (hasEvent && parentProject == nil) {
                let kind: ResourceKind = isLibrary ? .library : (isLegacyProject ? .legacyProject : .event)
                let project = buildProject(url: url, kind: kind, issues: &issues)
                projects.append(project)
                state.discoveredProjects = projects.count
                state.totalBytes += project.totalBytes
                state.cleanableBytes += project.cleanableBytes
                projectFound(project)
                emit(force: true)
            }

            for child in entries {
                guard !cancelled else { return }
                if isDirectory(child), !isSymlink(child) {
                    scanDirectory(child, parentProject: projectRoot)
                } else {
                    state.scannedFiles += 1
                }
            }
        }

        scanDirectory(root, parentProject: nil)
        state.isCancelled = cancelled
        state.issues = issues
        progress(state)

        return ScanResult(
            root: root,
            projects: projects.sorted { $0.cleanableBytes > $1.cleanableBytes },
            issues: issues,
            duration: Date().timeIntervalSince(started)
        )
    }

    private func buildProject(url: URL, kind: ResourceKind, issues: inout [ScanIssue]) -> ResourceItem {
        let total = measure(url)
        let groups = cacheGroups(in: url)
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return ResourceItem(name: url.lastPathComponent, kind: kind, url: url, totalBytes: total.bytes, modifiedAt: modified, cacheGroups: groups)
    }

    private func cacheGroups(in project: URL) -> [CacheGroup] {
        var buckets: [CacheType: [CacheTarget]] = [:]

        func walk(_ url: URL) {
            guard !cancelled else { return }
            for child in contents(of: url, issueHandler: nil) {
                guard isDirectory(child), !isSymlink(child) else { continue }
                if child != project && ["fcpbundle", "fcpproject"].contains(child.pathExtension.lowercased()) {
                    continue
                }

                if let type = cacheType(for: child) {
                    let measured = measure(child)
                    buckets[type, default: []].append(CacheTarget(url: child, bytes: measured.bytes, fileCount: measured.files, modifiedAt: measured.modifiedAt))
                } else {
                    walk(child)
                }
            }
        }

        walk(project)

        return CacheType.allCases.compactMap { type in
            guard let targets = buckets[type], !targets.isEmpty else { return nil }
            return CacheGroup(type: type, targets: targets)
        }.sorted { $0.bytes > $1.bytes }
    }

    private func cacheType(for url: URL) -> CacheType? {
        let name = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent

        if name == "Render Files" { return .renderFiles }
        if name == "Analysis Files" { return .analysisFiles }
        if name == "Waveform Cache Files" { return .waveformCache }
        if name == "Thumbnail Media" { return .thumbnailMedia }
        if parent == "Transcoded Media", name == "High Quality Media" { return .optimizedMedia }
        if parent == "Transcoded Media", name == "Proxy Media" { return .proxyMedia }
        if name == "Shared Items" { return .sharedItems }
        if name == "Original Media" { return .originalMedia }
        return nil
    }

    private func measure(_ url: URL) -> (bytes: Int64, files: Int, modifiedAt: Date?) {
        var bytes: Int64 = 0
        var files = 0
        var latest: Date?

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0, nil) }

        for case let file as URL in enumerator {
            if isSymlink(file) {
                enumerator.skipDescendants()
                continue
            }

            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            bytes += Int64(values?.fileSize ?? 0)
            files += 1
            if let modified = values?.contentModificationDate, latest == nil || modified > latest! {
                latest = modified
            }
        }

        return (bytes, files, latest)
    }

    private func contents(of url: URL, issueHandler: ((ScanIssue) -> Void)? = nil) -> [URL] {
        do {
            return try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            issueHandler?(ScanIssue(path: url.path, message: error.localizedDescription))
            return []
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}
