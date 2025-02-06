import SwiftUI
import AVFoundation

@Observable final class ThumbnailManager {
    private var cache: [String: UIImage] = [:]
    
    func thumbnail(for url: URL) async -> UIImage? {
        if let cached = cache[url.absoluteString] {
            return cached
        }
        
        do {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let cgImage = try await generator.image(at: .zero).image
            let thumbnail = UIImage(cgImage: cgImage)
            cache[url.absoluteString] = thumbnail
            return thumbnail
        } catch {
            print("❌ Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}
