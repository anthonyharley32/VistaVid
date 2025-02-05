import SwiftUI
import AVKit

struct FeedView: View {
    @StateObject private var viewModel = VideoViewModel()
    @StateObject private var videoManager = VideoPlayerManager()
    @State private var currentIndex: Int?
    @ObservedObject var authModel: AuthenticationViewModel
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
        // Set preferred status bar style in Info.plist instead
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
                                    .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                                    .offset(y: -geometry.safeAreaInsets.top)
                                    .id(index)
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentIndex)
                    .onChange(of: currentIndex) { oldValue, newValue in
                        print("📱 [FeedView]: Scrolled to video index: \(String(describing: newValue))")
                        if let index = newValue {
                            videoManager.pauseAllExcept(index: index)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .preferredColorScheme(.dark) // This will help with status bar appearance
        .environment(\.videoViewModel, viewModel)
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
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isLiked = false
    @State private var showComments = false
    @State private var likesCount: Int
    @State private var commentsCount: Int
    @State private var sharesCount: Int
    @Environment(\.videoViewModel) private var videoViewModel
    
    init(video: Video, index: Int, videoManager: VideoPlayerManager) {
        self.video = video
        self.index = index
        self.videoManager = videoManager
        _likesCount = State(initialValue: video.likesCount)
        _commentsCount = State(initialValue: video.commentsCount)
        _sharesCount = State(initialValue: video.sharesCount)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    CustomVideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: UIScreen.main.bounds.height)
                        .onAppear {
                            print("📱 [VideoPlayerView]: Video player appeared for index: \(index)")
                            videoManager.register(player: player, for: index)
                            player.play()
                        }
                        .onDisappear {
                            print("📱 [VideoPlayerView]: Video player disappeared for index: \(index)")
                            cleanupPlayer()
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
                                Button(action: {
                                    handleLike()
                                }) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 30))
                                        .foregroundColor(isLiked ? .red : .white)
                                }
                                Text("\(likesCount)")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                            }
                            
                            // Comment button
                            VStack(spacing: 4) {
                                Button(action: {
                                    showComments = true
                                }) {
                                    Image(systemName: "bubble.right.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                Text("\(commentsCount)")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                            }
                            
                            // Share button
                            VStack(spacing: 4) {
                                Button(action: {
                                    handleShare()
                                }) {
                                    Image(systemName: "arrowshape.turn.up.right.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                Text("\(sharesCount)")
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
        }
        .ignoresSafeArea()
        .onAppear {
            // Initialize player when view appears
            if player == nil, let videoURL = video.url {
                print("📱 [VideoPlayerView]: Initializing player for video: \(video.id)")
                let asset = AVAsset(url: videoURL)
                let item = AVPlayerItem(asset: asset)
                let newPlayer = AVQueuePlayer(playerItem: item)
                
                // Create player looper
                playerLooper = AVPlayerLooper(player: newPlayer, templateItem: item)
                
                // Configure player
                newPlayer.isMuted = false
                newPlayer.preventsDisplaySleepDuringVideoPlayback = true
                
                player = newPlayer
            }
            
            // Check if video is liked
            Task {
                do {
                    isLiked = try await videoViewModel.checkLikeStatus(for: video)
                } catch {
                    print("Error checking like status: \(error)")
                }
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
        .sheet(isPresented: $showComments) {
            CommentsView(video: video)
        }
    }
    
    private func cleanupPlayer() {
        if let currentPlayer = player {
            currentPlayer.pause()
            currentPlayer.removeAllItems()
            playerLooper?.disableLooping()
            playerLooper = nil
        }
        videoManager.unregister(index: index)
        player = nil
    }
    
    private func handleLike() {
        Task {
            do {
                try await videoViewModel.toggleLike(for: video)
                isLiked.toggle()
                likesCount = isLiked ? likesCount + 1 : likesCount - 1
            } catch {
                print("Error toggling like: \(error)")
            }
        }
    }
    
    private func handleShare() {
        videoViewModel.shareVideo(video)
        // Present system share sheet
        let activityVC = UIActivityViewController(
            activityItems: ["Check out this video on VistaVid!", video.url as Any],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func handleComment(text: String) async throws {
        try await videoViewModel.addComment(to: video, text: text)
        commentsCount += 1
    }
}

// MARK: - Video Player Manager
@MainActor
final class VideoPlayerManager: ObservableObject {
    private var players: [Int: AVQueuePlayer] = [:]
    private var currentIndex: Int?
    
    func register(player: AVQueuePlayer, for index: Int) {
        print("📱 [VideoPlayerManager]: Registering player for index: \(index)")
        players[index] = player
    }
    
    func unregister(index: Int) {
        print("📱 [VideoPlayerManager]: Unregistering player for index: \(index)")
        if let player = players[index] {
            player.pause()
            player.removeAllItems()
        }
        players.removeValue(forKey: index)
    }
    
    func pauseAllExcept(index: Int) {
        print("📱 [VideoPlayerManager]: Pausing all players except index: \(index)")
        
        // If we're switching to a new video, cleanup the old one
        if let oldIndex = currentIndex, oldIndex != index {
            unregister(index: oldIndex)
        }
        
        // Play the current video and pause all others
        for (playerIndex, player) in players {
            if playerIndex != index {
                player.pause()
            } else {
                player.play()
            }
        }
        
        currentIndex = index
    }
    
    func cleanup() {
        print("📱 [VideoPlayerManager]: Cleaning up all players")
        players.forEach { (index, player) in
            player.pause()
            player.removeAllItems()
        }
        players.removeAll()
        currentIndex = nil
    }
}

// MARK: - Models
struct VideoComment: Identifiable {
    let id: String
    let userId: String
    let text: String
    let createdAt: Date
}

struct CommentsView: View {
    let video: Video
    @Environment(\.videoViewModel) private var videoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [VideoComment] = []
    @State private var newComment: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else {
                    List(comments) { comment in
                        CommentCell(comment: comment)
                    }
                }
                
                // Comment input
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: {
                        submitComment()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(newComment.isEmpty)
                    .padding(.trailing)
                }
                .padding(.vertical)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadComments()
            }
        }
    }
    
    private func loadComments() {
        isLoading = true
        Task {
            do {
                let fetchedComments = try await videoViewModel.fetchComments(for: video)
                comments = fetchedComments.map { comment in
                    VideoComment(id: comment.id, userId: comment.userId, text: comment.text, createdAt: comment.createdAt)
                }
            } catch {
                print("Error loading comments: \(error)")
            }
            isLoading = false
        }
    }
    
    private func submitComment() {
        guard !newComment.isEmpty else { return }
        
        Task {
            do {
                try await videoViewModel.addComment(to: video, text: newComment)
                newComment = ""
                await loadComments()
            } catch {
                print("Error adding comment: \(error)")
            }
        }
    }
}

struct CommentCell: View {
    let comment: VideoComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("@user") // TODO: Fetch username from User model
                .font(.system(size: 14, weight: .bold))
            Text(comment.text)
                .font(.system(size: 14))
            Text(comment.createdAt, style: .relative)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Environment Keys
private struct VideoViewModelKey: EnvironmentKey {
    @MainActor static var defaultValue: VideoViewModel {
        VideoViewModel()
    }
}

extension EnvironmentValues {
    var videoViewModel: VideoViewModel {
        get { self[VideoViewModelKey.self] }
        set { self[VideoViewModelKey.self] = newValue }
    }
}

#Preview {
    FeedView(authModel: AuthenticationViewModel())
} 