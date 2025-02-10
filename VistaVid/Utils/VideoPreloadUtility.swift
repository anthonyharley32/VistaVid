import Foundation
import AVFoundation

// MARK: - Video Preload Utility
@MainActor
final class VideoPreloadUtility {
    private var preloadedAssets: [Int: AVURLAsset] = [:]
    private let preloadWindow = 1
    
    func preloadAdjacentVideos(around index: Int, videos: [Video]) async {
        print("🎬 [VideoPreloadUtility]: START Preloading adjacent videos around index \(index)")
        
        // Ensure we have videos to preload
        guard !videos.isEmpty else {
            print("🎬 [VideoPreloadUtility]: No videos available to preload")
            return
        }
        
        // Calculate preload range with bounds checking
        let startIndex = max(0, index - preloadWindow)
        let endIndex = min(videos.count - 1, index + preloadWindow)
        
        // Validate range
        guard startIndex <= endIndex else {
            print("🎬 [VideoPreloadUtility]: Invalid preload range: start(\(startIndex)) > end(\(endIndex))")
            return
        }
        
        // Aggressively clean up assets outside the preload window
        let indicesToRemove = preloadedAssets.keys.filter { $0 < startIndex - 1 || $0 > endIndex + 1 }
        for oldIndex in indicesToRemove {
            preloadedAssets.removeValue(forKey: oldIndex)
            print("🎬 [VideoPreloadUtility]: Cleaned up preloaded asset for index \(oldIndex)")
        }
        
        // Preload assets within the window, prioritizing the next video
        let preloadOrder = prioritizedPreloadOrder(currentIndex: index, start: startIndex, end: endIndex)
        
        for i in preloadOrder {
            // Skip if already preloaded
            guard preloadedAssets[i] == nil else {
                print("🎬 [VideoPreloadUtility]: Asset already preloaded for index \(i)")
                continue
            }
            
            // Get video URL
            guard i < videos.count,
                  let videoURL = videos[i].url else {
                print("🎬 [VideoPreloadUtility]: Invalid URL for video at index \(i)")
                continue
            }
            
            print("🎬 [VideoPreloadUtility]: Preloading asset for index \(i)")
            let asset = AVURLAsset(url: videoURL)
            
            // Configure resource loading
            asset.resourceLoader.preloadsEligibleContentKeys = true
            
            do {
                // Load essential properties first
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    print("🎬 [VideoPreloadUtility]: Asset is not playable for index \(i)")
                    continue
                }
                
                // If this is the next video, load more properties
                if i == index + 1 {
                    let duration = try await asset.load(.duration)
                    let tracks = try await asset.load(.tracks)
                    print("🎬 [VideoPreloadUtility]: Next video duration: \(duration.seconds)s, tracks: \(tracks.count)")
                }
                
                preloadedAssets[i] = asset
                print("✅ [VideoPreloadUtility]: Successfully preloaded asset for index \(i)")
            } catch {
                print("❌ [VideoPreloadUtility]: Failed to preload asset for index \(i): \(error)")
            }
        }
    }
    
    private func prioritizedPreloadOrder(currentIndex: Int, start: Int, end: Int) -> [Int] {
        var order: [Int] = []
        
        // First priority: next video
        if currentIndex + 1 <= end {
            order.append(currentIndex + 1)
        }
        
        // Second priority: previous video
        if currentIndex - 1 >= start {
            order.append(currentIndex - 1)
        }
        
        // Third priority: remaining videos in window
        for i in start...end {
            if !order.contains(i) && i != currentIndex {
                order.append(i)
            }
        }
        
        return order
    }
    
    func getPreloadedAsset(for index: Int) -> AVURLAsset? {
        return preloadedAssets[index]
    }
    
    func cleanup() {
        print("🎬 [VideoPreloadUtility]: Cleaning up all preloaded assets")
        preloadedAssets.removeAll()
    }
} 