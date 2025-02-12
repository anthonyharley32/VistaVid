import AVFoundation
import UIKit
import SwiftUI

final class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    
    private var cache: [String: UIImage] = [:]
    
    private init() {}
    
    func getThumbnail(for video: Video) async -> UIImage? {
        // Check cache first
        if let cachedImage = cache[video.id] {
            return cachedImage
        }
        
        guard let url = URL(string: video.videoUrl) else { return nil }
        
        // Generate thumbnail
        let image = await generateThumbnail(from: url)
        
        // Cache the result
        if let image = image {
            cache[video.id] = image
        }
        
        return image
    }
    
    private func generateThumbnail(from url: URL, at time: CMTime = CMTime(seconds: 1, preferredTimescale: 600)) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await assetImageGenerator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
    
    func clearCache() {
        cache.removeAll()
    }
} 