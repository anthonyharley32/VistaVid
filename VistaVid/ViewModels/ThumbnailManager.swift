import SwiftUI
import AVFoundation

@Observable final class ThumbnailManager {
    static let shared = ThumbnailManager() // Make it a singleton
    
    // MARK: - Properties
    private var cache: [String: UIImage] = [:]
    private let maxCacheSize = 100 // Increased from 50
    
    // MARK: - Public Methods
    func thumbnail(for url: URL) async -> UIImage? {
        print("🖼️ [ThumbnailManager]: Requesting thumbnail for \(url.lastPathComponent)")
        
        if let cached = cache[url.absoluteString] {
            print("✅ [ThumbnailManager]: Cache hit for \(url.lastPathComponent)")
            return cached
        }
        
        print("⏳ [ThumbnailManager]: Cache miss, generating thumbnail for \(url.lastPathComponent)")
        
        do {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400) // Limit thumbnail size
            
            let cgImage = try await generator.image(at: .zero).image
            let thumbnail = UIImage(cgImage: cgImage)
            
            // Manage cache size
            if cache.count >= maxCacheSize {
                cache.removeValue(forKey: cache.keys.first!)
            }
            
            cache[url.absoluteString] = thumbnail
            print("✅ [ThumbnailManager]: Successfully generated and cached thumbnail for \(url.lastPathComponent)")
            return thumbnail
        } catch {
            print("❌ [ThumbnailManager]: Failed to generate thumbnail: \(error)")
            return nil
        }
    }
    
    func clearCache() {
        print("🧹 [ThumbnailManager]: Clearing cache")
        cache.removeAll()
    }
    
    // Add preloading method
    func preloadThumbnails(for urls: [URL]) async {
        print("🖼️ [ThumbnailManager]: Preloading thumbnails for \(urls.count) videos")
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await self.thumbnail(for: url)
                }
            }
        }
    }
}
