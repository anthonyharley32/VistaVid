import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let shouldPlay: Bool
    @State private var player: AVPlayer?
    @State private var showPlayButton = false
    @State private var isPlaying = true
    
    // Configure cache size - 500MB for memory, 1GB for disk
    private static let cache: URLCache = {
        let memoryCapacity = 500 * 1024 * 1024 // 500 MB
        let diskCapacity = 1024 * 1024 * 1024 // 1 GB
        return URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
    }()
    
    private func loadVideoWithCache() -> AVPlayer {
        // Create URL request
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        // Create asset with caching configuration
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetOutOfBandMIMETypeKey": "video/mp4",
            "AVURLAssetHTTPHeaderFieldsKey": ["Cache-Control": "max-age=86400"]
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        return AVPlayer(playerItem: playerItem)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func monitorAssetSize() {
        Task {
            do {
                let asset = AVURLAsset(url: url)
                if let tracks = try? await asset.load(.tracks) {
                    var totalSize: Int64 = 0
                    
                    for track in tracks {
                        if let size = try? await track.load(.totalSampleDataLength) {
                            totalSize += size
                        }
                    }
                    
                    print("🎥 Video loaded - URL: \(url.lastPathComponent)")
                    print("📊 Estimated size: \(formatFileSize(totalSize))")
                    
                    // Print cache status
                    if let cachedResponse = Self.cache.cachedResponse(for: URLRequest(url: url)) {
                        print("💾 Video is cached - Size in cache: \(formatFileSize(Int64(cachedResponse.data.count)))")
                    }
                }
            } catch {
                print("❌ Error monitoring asset size: \(error)")
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
            CustomVideoPlayer(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            if showPlayButton || !isPlaying {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.8))
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle()) // Makes entire area tappable
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showPlayButton = true
            }
            
            // Toggle play state
            isPlaying.toggle()
            if isPlaying {
                player?.play()
                // Only auto-hide if we're playing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPlayButton = false
                    }
                }
            } else {
                player?.pause()
            }
        }
        .onChange(of: shouldPlay) { newValue in
            isPlaying = newValue
            if newValue {
                player?.play()
                // Auto-hide when starting to play
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPlayButton = false
                }
            } else {
                player?.pause()
            }
        }
        .onAppear {
            // Configure URLCache to use our settings
            URLCache.shared = Self.cache
            
            // Create and setup player with caching
            player = loadVideoWithCache()
            
            // Monitor data usage
            monitorAssetSize()
            
            // Configure player
            player?.actionAtItemEnd = .none
            player?.isMuted = false  // Start unmuted by default
            isPlaying = shouldPlay
            showPlayButton = !shouldPlay // Show play button if starting paused
            
            // Only play if this is the current video
            if shouldPlay {
                player?.play()
            }
            
            // Add loop behavior
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                if shouldPlay {
                    player?.play()
                }
            }
        }
        .onDisappear {
            // Cleanup
            player?.pause()
            player = nil
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// Custom UIViewControllerRepresentable to create a clean video player without controls
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // Hide default controls
        controller.view.backgroundColor = .black  // Set background color to black
        
        // Set initial gravity to aspect (centered)
        controller.videoGravity = .resizeAspect
        
        // Check video dimensions and update gravity accordingly
        if let playerItem = player?.currentItem {
            let tracks = playerItem.asset.tracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                let isPortrait = abs(size.height) > abs(size.width)
                controller.videoGravity = isPortrait ? .resizeAspectFill : .resizeAspect
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
} 