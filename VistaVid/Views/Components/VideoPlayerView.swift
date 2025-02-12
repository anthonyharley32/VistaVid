import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let shouldPlay: Bool
    let video: Video?
    @StateObject private var videoModel = VideoViewModel()
    @State private var player: AVPlayer?
    @State private var showPlayButton = false
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
            
            let playerItem = AVPlayerItem(asset: asset)
            
            // Create player on the main thread
            await MainActor.run {
                player = AVPlayer(playerItem: playerItem)
                player?.actionAtItemEnd = .none
                player?.isMuted = false
                
                if shouldPlay {
                    player?.play()
                }
                
                isLoading = false
            }
            
            print("✅ Successfully loaded video")
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
                
                if showPlayButton || !isPlaying {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.8))
                        .transition(.opacity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showPlayButton = true
            }
            
            isPlaying.toggle()
            if isPlaying {
                player?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPlayButton = false
                    }
                }
                
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
                player?.pause()
            }
        }
        .onChange(of: shouldPlay) { newValue in
            isPlaying = newValue
            if newValue {
                player?.play()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPlayButton = false
                }
                
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
                player?.pause()
            }
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
            showPlayButton = !shouldPlay
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
        
        // Always use resizeAspect to maintain proper video proportions
        controller.videoGravity = .resizeAspect
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
} 