import Foundation

struct CleanProgress {
    let currentPath: String
    let completed: Int
    let total: Int
    let cleanedBytes: Int64
    let failures: [ScanIssue]
}

struct CleanResult {
    let cleanedBytes: Int64
    let succeeded: Int
    let failed: [ScanIssue]
}

final class FCPXCleanerCore {
    func clean(targets: [CacheTarget], progress: @escaping (CleanProgress) -> Void) -> CleanResult {
        var cleanedBytes: Int64 = 0
        var succeeded = 0
        var failures: [ScanIssue] = []

        for (index, target) in targets.enumerated() {
            progress(CleanProgress(currentPath: target.url.path, completed: index, total: targets.count, cleanedBytes: cleanedBytes, failures: failures))
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: target.url, resultingItemURL: &resultingURL)
                cleanedBytes += target.bytes
                succeeded += 1
            } catch {
                failures.append(ScanIssue(path: target.url.path, message: error.localizedDescription))
            }
        }

        progress(CleanProgress(currentPath: "", completed: targets.count, total: targets.count, cleanedBytes: cleanedBytes, failures: failures))
        return CleanResult(cleanedBytes: cleanedBytes, succeeded: succeeded, failed: failures)
    }
}
