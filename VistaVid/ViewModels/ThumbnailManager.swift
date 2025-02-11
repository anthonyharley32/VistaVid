import SwiftUI
import AVFoundation
import FirebaseStorage

@Observable final class ThumbnailManager {
    static let shared = ThumbnailManager()
    
    // MARK: - Properties
    private var cache: [String: UIImage] = [:]
    private let maxCacheSize = 100
    private let storage = Storage.storage()
    
    // MARK: - Public Methods
    func thumbnail(for video: Video) async -> UIImage? {
        print("🖼️ [ThumbnailManager]: Requesting thumbnail for video \(video.id)")
        
        // 1. Check memory cache first
        if let cached = cache[video.id] {
            print("✅ [ThumbnailManager]: Cache hit for \(video.id)")
            return cached
        }
        
        // 2. Try to get stored thumbnail from Firebase
        if let thumbnailUrl = video.thumbnailUrl,
           let url = URL(string: thumbnailUrl),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let image = UIImage(data: data) {
            print("✅ [ThumbnailManager]: Retrieved stored thumbnail for \(video.id)")
            addToCache(image, for: video.id)
            return image
        }
        
        // 3. Generate thumbnail only if necessary (fallback)
        guard let videoUrl = video.url else {
            print("❌ [ThumbnailManager]: No video URL available")
            return nil
        }
        
        print("⚠️ [ThumbnailManager]: No stored thumbnail found, generating for \(video.id)")
        return await generateThumbnail(from: videoUrl, for: video.id)
    }
    
    func preloadThumbnails(for videos: [Video]) async {
        print("🖼️ [ThumbnailManager]: Preloading thumbnails for \(videos.count) videos")
        await withTaskGroup(of: Void.self) { group in
            for video in videos {
                group.addTask {
                    _ = await self.thumbnail(for: video)
                }
            }
        }
    }
    
    func clearCache() {
        print("🧹 [ThumbnailManager]: Clearing cache")
        cache.removeAll()
    }
    
    // MARK: - Private Methods
    private func addToCache(_ image: UIImage, for key: String) {
        if cache.count >= maxCacheSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[key] = image
    }
    
    private func generateThumbnail(from url: URL, for videoId: String) async -> UIImage? {
        do {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)
            
            let cgImage = try await generator.image(at: .zero).image
            let thumbnail = UIImage(cgImage: cgImage)
            addToCache(thumbnail, for: videoId)
            return thumbnail
        } catch {
            print("❌ [ThumbnailManager]: Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}
