import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let shouldPlay: Bool
    let video: Video?
    @StateObject private var videoModel = VideoViewModel()
    @State private var player: AVPlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isPlaying = true
    @State private var hasTrackedView = false
    @State private var isLoading = true
    @State private var loadError: Error?
    
    // Configure cache size - 500MB for memory, 1GB for disk
    private static let cache: URLCache = {
        let memoryCapacity = 500 * 1024 * 1024 // 500 MB
        let diskCapacity = 1024 * 1024 * 1024 // 1 GB
        return URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
    }()
    
    private func loadVideoWithCache() async {
        print("🎥 Loading video from URL: \(url)")
        isLoading = true
        
        do {
            // Create URL request with caching
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            
            // Create asset with caching configuration
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetOutOfBandMIMETypeKey": "video/mp4",
                "AVURLAssetHTTPHeaderFieldsKey": ["Cache-Control": "max-age=86400"]
            ])
            
            // Load the asset's tracks asynchronously
            _ = try await asset.load(.tracks)
            
            // Create a player item template for looping
            let playerItem = AVPlayerItem(asset: asset)
            
            // Create player and looper on the main thread
            await MainActor.run {
                let queuePlayer = AVQueuePlayer()
                player = queuePlayer
                
                // Create player looper with the queue player
                playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
                
                player?.isMuted = false
                
                if shouldPlay {
                    player?.play()
                }
                
                isLoading = false
            }
            
            print("✅ Successfully loaded video with looping enabled")
        } catch {
            print("❌ Error loading video: \(error)")
            await MainActor.run {
                loadError = error
                isLoading = false
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func monitorAssetSize() {
        Task {
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
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)
                    Text("Failed to load video")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                }
                .padding()
            } else if let player = player {
                CustomVideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isPlaying.toggle()
            handlePlayPauseChange()
        }
        .onChange(of: shouldPlay) { oldValue, newValue in
            print("👁️ [VideoPlayerView] shouldPlay changed to: \(newValue)")
            isPlaying = newValue
            handlePlayPauseChange()
        }
        .task {
            // Configure URLCache to use our settings
            URLCache.shared = Self.cache
            
            // Load video asynchronously
            await loadVideoWithCache()
            
            // Monitor data usage
            monitorAssetSize()
            
            // Configure initial state
            isPlaying = shouldPlay
        }
        .onDisappear {
            // Cleanup
            player?.pause()
            playerLooper?.disableLooping()  // Disable looping
            playerLooper = nil  // Release the looper
            player = nil
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func handlePlayPauseChange() {
        if isPlaying {
            print("👁️ [VideoPlayerView] Playing video")
            player?.play()
            
            // Track view after 1 second of playback
            if !hasTrackedView, let video = video {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if isPlaying {
                        try? await videoModel.incrementViewCount(for: video)
                        hasTrackedView = true
                    }
                }
            }
        } else {
            print("👁️ [VideoPlayerView] Pausing video")
            player?.pause()
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
        
        // Always use resizeAspect to maintain proper video proportions
        controller.videoGravity = .resizeAspect
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
} 