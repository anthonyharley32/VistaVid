import SwiftUI
import AVKit

// MARK: - Feed Content View
private struct FeedContentView: View {
    let geometry: GeometryProxy
    let videos: [Video]
    let videoManager: VideoPlayerManager
    @Binding var currentIndex: Int?
    @Binding var visibleIndex: Int?
    @Binding var selectedUser: User?
    let authModel: AuthenticationViewModel
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    VideoPlayerView(video: video, 
                                  index: index, 
                                  videoManager: videoManager,
                                  isVisible: visibleIndex == index,
                                  onUserTap: { handleUserTap(video: video) })
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onAppear {
                            print(" [FeedView]: Video \(index) appeared")
                            if currentIndex == nil {
                                currentIndex = index
                                visibleIndex = index
                            }
                        }
                        .modifier(VisibilityModifier(index: index, currentVisibleIndex: $visibleIndex))
                        .onDisappear {
                            print(" [FeedView]: Video \(index) disappeared")
                        }
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentIndex)
    }
    
    private func handleUserTap(video: Video) {
        if video.user?.id == authModel.currentUser?.id {
            print(" [FeedView]: Navigating to You tab")
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToYouTab"), object: nil)
        } else {
            print(" [FeedView]: Navigating to UserProfileView")
            selectedUser = video.user
        }
    }
}

struct FeedView: View {
    @StateObject private var viewModel = VideoViewModel()
    @StateObject private var videoManager = VideoPlayerManager()
    @State private var currentIndex: Int?
    @State private var visibleIndex: Int?
    @ObservedObject var authModel: AuthenticationViewModel
    @State private var selectedUser: User?
    @State private var currentlyPlayingVideo: String? = nil
    @State private var isPaused = false
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.videos.isEmpty {
                    Text("No videos available")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    FeedContentView(
                        geometry: geometry,
                        videos: viewModel.videos,
                        videoManager: videoManager,
                        currentIndex: $currentIndex,
                        visibleIndex: $visibleIndex,
                        selectedUser: $selectedUser,
                        authModel: authModel
                    )
                    .onChange(of: visibleIndex) { oldValue, newValue in
                        print(" [FeedView]: Visible index changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                        if let index = newValue {
                            videoManager.pauseAllExcept(index: index)
                        } else {
                            videoManager.cleanup()
                        }
                    }
                    .onDisappear {
                        videoManager.cleanup()
                    }
                }
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .statusBar(hidden: true)
            .environment(\.videoViewModel, viewModel)
            .onAppear {
                Task {
                    await viewModel.loadVideos()
                }
            }
            .navigationDestination(item: $selectedUser) { user in
                UserProfileView(user: user)
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
            print(" [VideoCell]: Loading video cell for \(video.id)")
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    let video: Video
    let index: Int
    let videoManager: VideoPlayerManager
    let isVisible: Bool
    let onUserTap: () -> Void
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isLoading = false
    @State private var isPlaying = false
    @State private var showPlaybackIndicator = false
    @State private var thumbnail: UIImage?
    @State private var isVideoReady = false
    @State private var isLiked = false
    @State private var showComments = false
    
    // Like, comment, share counts
    @State private var likesCount: Int
    @State private var commentsCount: Int
    @State private var sharesCount: Int
    
    let thumbnailManager = ThumbnailManager()
    @Environment(\.videoViewModel) private var videoViewModel
    
    init(video: Video, index: Int, videoManager: VideoPlayerManager, isVisible: Bool, onUserTap: @escaping () -> Void) {
        self.video = video
        self.index = index
        self.videoManager = videoManager
        self.isVisible = isVisible
        self.onUserTap = onUserTap
        _likesCount = State(initialValue: video.likesCount)
        _commentsCount = State(initialValue: video.commentsCount)
        _sharesCount = State(initialValue: video.sharesCount)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: UIScreen.main.bounds.height)
                        .clipped()
                }
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                if let player = player, isVisible, isVideoReady {
                    CustomVideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: UIScreen.main.bounds.height)
                        .clipped()
                        .onAppear {
                            print(" [VideoPlayerView \(index)]: Player view appeared, isVisible: \(isVisible)")
                        }
                        .onDisappear {
                            print(" [VideoPlayerView \(index)]: Player view disappeared")
                            cleanupPlayer()
                        }
                }
                
                // Playback indicator
                if showPlaybackIndicator {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Video Info Overlay
                ZStack(alignment: .bottom) {
                    // Left side content (username and description)
                    HStack(alignment: .bottom) {
                        // Description and username
                        VStack(alignment: .leading, spacing: 10) {
                            // Username and description container
                            VStack(alignment: .leading, spacing: 8) {
                                Text("@\(video.user?.username ?? "unknown")")
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
                            if let profilePicUrl = video.user?.profilePicUrl,
                               let url = URL(string: profilePicUrl) {
                                Button(action: onUserTap) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            Circle()
                                                .fill(Color.gray.opacity(0.5))
                                                .frame(width: 50, height: 50)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        case .failure:
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .foregroundColor(.white)
                                                )
                                        @unknown default:
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 50, height: 50)
                                        }
                                    }
                                }
                            } else {
                                Button(action: onUserTap) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            
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
        .onChange(of: isVisible) { oldValue, newValue in
            print(" [VideoPlayerView \(index)]: Visibility changed: \(oldValue) -> \(newValue)")
            Task {
                if newValue {
                    await initializePlayerIfNeeded()
                } else {
                    cleanupPlayer()
                }
            }
        }
        .onAppear {
            print(" [VideoPlayerView \(index)]: View appeared, isVisible: \(isVisible)")
            if isVisible {
                Task {
                    await initializePlayerIfNeeded()
                }
            }
        }
        .onDisappear {
            print(" [VideoPlayerView \(index)]: View disappeared")
            cleanupPlayer()
        }
        .sheet(isPresented: $showComments) {
            CommentsView(video: video)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TogglePlayback"))) { notification in
            if let videoId = notification.userInfo?["videoId"] as? String,
               videoId == video.id {
                if player?.timeControlStatus == .playing {
                    player?.pause()
                } else {
                    player?.play()
                }
            }
        }
    }
    
    private func initializePlayerIfNeeded() async {
        print(" [VideoPlayerView \(index)]: START Initializing player")
        guard player == nil, 
              let videoURL = video.url else { 
            print(" [VideoPlayerView \(index)]: Invalid video URL")
            return 
        }
        
        // Load thumbnail first
        if thumbnail == nil {
            thumbnail = await thumbnailManager.thumbnail(for: videoURL)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Try to get preloaded asset first
        let asset = videoManager.getPreloadedAsset(for: index) ?? AVURLAsset(url: videoURL)
        
        // Wait for asset to load if not preloaded
        if videoManager.getPreloadedAsset(for: index) == nil {
            print(" [VideoPlayerView \(index)]: Loading asset (not preloaded)")
            _ = try? await asset.load(.isPlayable)
        } else {
            print(" [VideoPlayerView \(index)]: Using preloaded asset")
        }
        
        // Only proceed if still visible
        guard isVisible else {
            print(" [VideoPlayerView \(index)]: No longer visible during initialization")
            return
        }
        
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: newPlayer, templateItem: item)
        
        // Configure player
        newPlayer.isMuted = false
        newPlayer.preventsDisplaySleepDuringVideoPlayback = true
        
        // Add observer for when the video is ready to play
        let timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak newPlayer] _ in
            guard let player = newPlayer else { return }
            if !isVideoReady && player.currentItem?.status == .readyToPlay {
                isVideoReady = true
                print(" [VideoPlayerView \(index)]: Video is ready to play")
            }
        }
        
        // Final visibility check before committing
        if isVisible {
            print(" [VideoPlayerView \(index)]: Setting up new player")
            player = newPlayer
            videoManager.register(player: newPlayer, for: index)
            newPlayer.play()
            isPlaying = true
        } else {
            print(" [VideoPlayerView \(index)]: Lost visibility during final setup")
            newPlayer.pause()
            playerLooper?.disableLooping()
            newPlayer.removeTimeObserver(timeObserverToken)
        }
    }
    
    private func cleanupPlayer() {
        print(" [VideoPlayerView \(index)]: START Cleanup, player exists: \(player != nil)")
        
        if let currentPlayer = player {
            print(" [VideoPlayerView \(index)]: Pausing and cleaning up player")
            currentPlayer.pause()
            currentPlayer.removeAllItems()
            playerLooper?.disableLooping()
            playerLooper = nil
            videoManager.unregister(index: index)
            player = nil
            isPlaying = false
        }
        
        print(" [VideoPlayerView \(index)]: END Cleanup")
    }
    
    private func handlePlayPause() {
        guard let player = player else { return }
        
        isPlaying.toggle()
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
        
        // Show indicator with animation
        withAnimation {
            showPlaybackIndicator = true
        }
        
        // Hide indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showPlaybackIndicator = false
            }
        }
        
        print(" [VideoPlayerView]: Video playback toggled to \(isPlaying ? "playing" : "paused")")
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
    private var preloadedAssets: [Int: AVURLAsset] = [:]
    private var currentIndex: Int?
    private var timeObserverTokens: [Int: Any] = [:]
    private let preloadWindow = 2
    @Environment(\.videoViewModel) private var videoViewModel: VideoViewModel
    
    func register(player: AVQueuePlayer, for index: Int) {
        print(" [VideoPlayerManager]: START Registering player for index: \(index)")
        
        // Remove any existing player for this index
        unregister(index: index)
        
        // Add periodic time observer
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak player] _ in
            guard let player = player else { return }
            if player.timeControlStatus == .playing {
                print(" [VideoPlayerManager]: Player \(index) is actively playing")
            }
        }
        
        // Store the new player and its observer
        players[index] = player
        timeObserverTokens[index] = timeObserver
        currentIndex = index
        
        // Preload adjacent videos
        Task {
            await preloadAdjacentVideos(around: index)
        }
    }
    
    func getPreloadedAsset(for index: Int) -> AVURLAsset? {
        return preloadedAssets[index]
    }
    
    private func preloadAdjacentVideos(around index: Int) async {
        print(" [VideoPlayerManager]: START Preloading adjacent videos around index \(index)")
        
        // Ensure we have videos to preload
        guard !videoViewModel.videos.isEmpty else {
            print(" [VideoPlayerManager]: No videos to preload")
            return
        }
        
        // Calculate preload range with bounds checking
        let startIndex = max(0, index - preloadWindow)
        let endIndex = min(videoViewModel.videos.count - 1, index + preloadWindow)
        
        // Validate range
        guard startIndex <= endIndex else {
            print(" [VideoPlayerManager]: Invalid range: start(\(startIndex)) > end(\(endIndex))")
            return
        }
        
        // Clean up assets outside the preload window
        let indicesToRemove = preloadedAssets.keys.filter { $0 < startIndex || $0 > endIndex }
        for oldIndex in indicesToRemove {
            preloadedAssets.removeValue(forKey: oldIndex)
            print(" [VideoPlayerManager]: Removed preloaded asset for index \(oldIndex)")
        }
        
        // Preload assets within the window
        for i in startIndex...endIndex {
            // Skip if already preloaded
            guard preloadedAssets[i] == nil else {
                print(" [VideoPlayerManager]: Asset already preloaded for index \(i)")
                continue
            }
            
            // Skip if video URL is missing or invalid
            guard let videoURL = videoViewModel.videos[i].url else {
                print(" [VideoPlayerManager]: Invalid URL for video at index \(i)")
                continue
            }
            
            print(" [VideoPlayerManager]: Preloading asset for index \(i)")
            let asset = AVURLAsset(url: videoURL)
            do {
                _ = try await asset.load(.isPlayable)
                preloadedAssets[i] = asset
                print(" [VideoPlayerManager]: Successfully preloaded asset for index \(i)")
            } catch {
                print(" [VideoPlayerManager]: Failed to preload asset for index \(i): \(error)")
            }
        }
        
        print(" [VideoPlayerManager]: END Preloading adjacent videos")
    }
    
    func unregister(index: Int) {
        print(" [VideoPlayerManager]: START Unregistering player for index: \(index)")
        
        if let player = players[index] {
            // Remove time observer
            if let token = timeObserverTokens[index] {
                player.removeTimeObserver(token)
                timeObserverTokens.removeValue(forKey: index)
            }
            
            // Cleanup player
            player.pause()
            player.replaceCurrentItem(with: nil)
            player.removeAllItems()
        }
        
        players.removeValue(forKey: index)
        
        if currentIndex == index {
            currentIndex = nil
        }
    }
    
    func pauseAllExcept(index: Int) {
        // First, cleanup all players except the target index
        let playersToRemove = players.keys.filter { $0 != index }
        for playerIndex in playersToRemove {
            unregister(index: playerIndex)
        }
        
        // Now handle the current player
        if let player = players[index] {
            player.seek(to: .zero)
            player.play()
            currentIndex = index
            
            // Preload adjacent videos
            Task {
                await preloadAdjacentVideos(around: index)
            }
        }
    }
    
    func cleanup() {
        // Remove all time observers and cleanup players
        for (index, player) in players {
            if let token = timeObserverTokens[index] {
                player.removeTimeObserver(token)
            }
            player.pause()
            player.replaceCurrentItem(with: nil)
            player.removeAllItems()
        }
        
        players.removeAll()
        timeObserverTokens.removeAll()
        preloadedAssets.removeAll()
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
                loadComments()
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