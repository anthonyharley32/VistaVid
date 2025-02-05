import SwiftUI
import AVKit

struct FeedView: View {
    @StateObject private var viewModel = VideoViewModel()
    @StateObject private var videoManager = VideoPlayerManager()
    @State private var currentIndex: Int?
    @ObservedObject var authModel: AuthenticationViewModel
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        print("📱 [FeedView]: Showing loading indicator")
                    }
            } else if viewModel.videos.isEmpty {
                Text("No videos available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        print("📱 [FeedView]: No videos to display")
                    }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                            VideoPlayerView(video: video, index: index, videoManager: videoManager)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentIndex)
                .onChange(of: currentIndex) { oldValue, newValue in
                    print("📱 [FeedView]: Scrolled to video index: \(String(describing: newValue))")
                    // Pause all videos except the current one
                    if let index = newValue {
                        videoManager.pauseAllExcept(index: index)
                    }
                }
                .ignoresSafeArea()
                .statusBar(hidden: true)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            print("📱 [FeedView]: View appeared")
            Task {
                print("📱 [FeedView]: Loading videos")
                await viewModel.loadVideos()
            }
        }
    }
}

struct VideoCell: View {
    let video: Video
    
    var body: some View {
        VStack {
            if let url = video.url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "video.slash.fill")
                            .font(.largeTitle)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            Text(video.description)
                .padding()
        }
        .onAppear {
            print("📱 [VideoCell]: Loading video cell for \(video.id)")
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    let video: Video
    let index: Int
    let videoManager: VideoPlayerManager
    
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        print("📱 [VideoPlayerView]: Video player appeared for index: \(index)")
                        videoManager.register(player: player, for: index)
                        player.play()
                    }
                    .onDisappear {
                        print("📱 [VideoPlayerView]: Video player disappeared for index: \(index)")
                        player.pause()
                    }
            }
            
            // Video Info Overlay
            ZStack(alignment: .bottom) {
                // Left side content (username and description)
                HStack(alignment: .bottom) {
                    // Description and username
                    VStack(alignment: .leading, spacing: 10) {
                        // Username and description container
                        VStack(alignment: .leading, spacing: 8) {
                            Text("@username")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                            
                            Text(video.description)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                            
                            if !video.algorithmTags.isEmpty {
                                HStack(spacing: 5) {
                                    ForEach(video.algorithmTags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 100)
                    
                    Spacer(minLength: 80) // Force spacing between description and buttons
                    
                    // Right side buttons
                    VStack(alignment: .center, spacing: 20) {
                        // Profile picture
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                        
                        // Like button
                        VStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("0")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                        
                        // Comment button
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.right.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("0")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                        
                        // Share button
                        VStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.right.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("Share")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .onAppear {
            // Initialize player when view appears
            if player == nil, let videoURL = video.url {
                print("📱 [VideoPlayerView]: Initializing player for video: \(video.id)")
                player = AVPlayer(url: videoURL)
            }
        }
    }
}

// MARK: - Video Player Manager
@MainActor
final class VideoPlayerManager: ObservableObject {
    private var players: [Int: AVPlayer] = [:]
    
    func register(player: AVPlayer, for index: Int) {
        print("📱 [VideoPlayerManager]: Registering player for index: \(index)")
        players[index] = player
    }
    
    func pauseAllExcept(index: Int) {
        print("📱 [VideoPlayerManager]: Pausing all players except index: \(index)")
        for (playerIndex, player) in players {
            if playerIndex != index {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    func cleanup() {
        print("📱 [VideoPlayerManager]: Cleaning up all players")
        players.values.forEach { player in
            player.pause()
        }
        players.removeAll()
    }
}

#Preview {
    FeedView(authModel: AuthenticationViewModel())
} 