import SwiftUI
import AppKit
import ImageIO

/// 缩略图缓存：按 (URL, 目标像素) 缓存已降采样的图片，避免重复从磁盘解码全分辨率 PNG。
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 96 * 1024 * 1024 // ~96MB 上限
    }

    func image(for url: URL, maxPixel: CGFloat) -> NSImage? {
        let key = "\(url.path)#\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let img = Self.downsample(url: url, maxPixel: maxPixel) else { return nil }
        let cost = img.representations.first.map { $0.pixelsWide * $0.pixelsHigh * 4 } ?? 0
        cache.setObject(img, forKey: key, cost: cost)
        return img
    }

    /// 用 ImageIO 直接解码到目标尺寸，内存与耗时都远低于加载全图再缩放。
    private static func downsample(url: URL, maxPixel: CGFloat) -> NSImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

/// 异步加载并降采样本地 PNG 海报，加载期间显示占位。
struct ThumbnailView: View {
    let url: URL?
    var maxPixel: CGFloat = 240
    var isDarkBackground: Bool = false
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if isDarkBackground {
                Color(hex: 0x1F1F1F) // 固定深色背景，用于凸显透明字幕/标题
            }

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                if !isDarkBackground {
                    Rectangle().fill(Theme.border.opacity(0.4))
                }
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .task(id: url) {
            image = nil
            guard let url else { return }
            let px = maxPixel
            let loaded = await Task.detached(priority: .utility) {
                ThumbnailCache.shared.image(for: url, maxPixel: px)
            }.value
            if !Task.isCancelled { image = loaded }
        }
    }
}
