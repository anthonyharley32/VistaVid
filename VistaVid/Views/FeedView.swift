import SwiftUI
import AVKit

struct FeedView: View {
    @StateObject private var viewModel = VideoViewModel()
    @StateObject private var videoManager = VideoPlayerManager()
    @State private var currentIndex: Int?
    @State private var visibleIndex: Int?
    @ObservedObject var authModel: AuthenticationViewModel
    @State private var currentlyPlayingVideo: String? = nil
    @State private var isPaused = false
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.videos.isEmpty {
                Text("No videos available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                            VideoPlayerView(video: video, 
                                          index: index, 
                                          videoManager: videoManager,
                                          isVisible: visibleIndex == index)
                                .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                                .offset(y: -geometry.safeAreaInsets.top)
                                .id(index)
                                .modifier(VisibilityModifier(index: index, currentVisibleIndex: $visibleIndex))
                                .onTapGesture { location in
                                    let frame = CGRect(x: 0, y: 0, width: geometry.size.width, height: geometry.size.height)
                                    
                                    // Use relative dimensions
                                    let rightSideWidth = frame.width * 0.2 // 20% of screen width
                                    let engagementAreaHeight = frame.height * 0.4 // 40% of screen height
                                    
                                    // Profile picture area (just above like button)
                                    let profileStartY = frame.height - engagementAreaHeight // Start of engagement area
                                    let profileHeight = frame.height * 0.1 // Height for profile picture area
                                    
                                    print(" [FeedView]: Tap location - x: \(location.x), y: \(location.y)")
                                    print(" [FeedView]: Frame - width: \(frame.width), height: \(frame.height)")
                                    print(" [FeedView]: Profile area - right: \(frame.width - rightSideWidth), y: \(profileStartY)")
                                    
                                    // Check tap zones
                                    let isInEngagementArea = location.x > (frame.width - rightSideWidth) && 
                                                           location.y > profileStartY
                                    let isInProfileArea = location.x > (frame.width - rightSideWidth) && 
                                                        location.y > profileStartY &&
                                                        location.y < (profileStartY + profileHeight)
                                    
                                    print(" [FeedView]: isInProfileArea: \(isInProfileArea)")
                                    print(" [FeedView]: Current user id: \(String(describing: authModel.currentUser?.id))")
                                    print(" [FeedView]: Video user id: \(String(describing: video.user?.id))")
                                    
                                    if isInProfileArea {
                                        // Navigate to You tab
                                        if video.user?.id == authModel.currentUser?.id {
                                            print(" [FeedView]: Navigating to You tab")
                                            NotificationCenter.default.post(name: NSNotification.Name("NavigateToYouTab"), object: nil)
                                        }
                                    } else if !isInEngagementArea {
                                        isPaused.toggle()
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("TogglePlayback"),
                                            object: nil,
                                            userInfo: ["videoId": video.id]
                                        )
                                    }
                                }
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentIndex)
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
                .ignoresSafeArea()
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
    
    @State private var isPlaying = true
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var isLiked = false
    @State private var showComments = false
    @State private var likesCount: Int
    @State private var commentsCount: Int
    @State private var sharesCount: Int
    @State private var showPlaybackIndicator = false
    @Environment(\.videoViewModel) private var videoViewModel
    @State private var isLoading = false
    
    init(video: Video, index: Int, videoManager: VideoPlayerManager, isVisible: Bool) {
        self.video = video
        self.index = index
        self.videoManager = videoManager
        self.isVisible = isVisible
        _likesCount = State(initialValue: video.likesCount)
        _commentsCount = State(initialValue: video.commentsCount)
        _sharesCount = State(initialValue: video.sharesCount)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                if let player = player, isVisible {
                    CustomVideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: UIScreen.main.bounds.height)
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
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Circle()
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                ProgressView()
                                                    .foregroundColor(.white)
                                            )
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                    case .failure:
                                        Circle()
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    )
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
        print(" [VideoPlayerView \(index)]: START Initializing player, current player exists: \(player != nil)")
        guard player == nil, let videoURL = video.url else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            print(" [VideoPlayerView \(index)]: Creating new player")
            let asset = AVURLAsset(url: videoURL)
            
            // Wait for asset to load
            print(" [VideoPlayerView \(index)]: Loading asset")
            _ = try await asset.load(.isPlayable)
            
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
            }
        } catch {
            print(" [VideoPlayerView \(index)]: Failed to initialize player: \(error)")
        }
        
        print(" [VideoPlayerView \(index)]: END Initializing player")
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
    private var currentIndex: Int?
    private var timeObserverTokens: [Int: Any] = [:]
    
    func register(player: AVQueuePlayer, for index: Int) {
        print(" [VideoPlayerManager]: START Registering player for index: \(index)")
        print(" [VideoPlayerManager]: Current active players: \(players.keys.sorted())")
        print(" [VideoPlayerManager]: Current index before: \(String(describing: currentIndex))")
        
        // Remove any existing player for this index
        unregister(index: index)
        
        // Add periodic time observer
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak player] _ in
            guard let player = player else {
                print(" [VideoPlayerManager]: Player \(index) was deallocated")
                return
            }
            
            print(" [VideoPlayerManager]: Player \(index) status - Rate: \(player.rate), Time Control Status: \(player.timeControlStatus.rawValue)")
            if player.timeControlStatus == .playing {
                print(" [VideoPlayerManager]: Player \(index) is actively playing")
            }
        }
        
        // Store the new player and its observer
        players[index] = player
        timeObserverTokens[index] = timeObserver
        
        print(" [VideoPlayerManager]: END Registering player for index: \(index)")
        print(" [VideoPlayerManager]: Updated active players: \(players.keys.sorted())")
    }
    
    func unregister(index: Int) {
        print(" [VideoPlayerManager]: START Unregistering player for index: \(index)")
        print(" [VideoPlayerManager]: Current active players before unregister: \(players.keys.sorted())")
        
        if let player = players[index] {
            print(" [VideoPlayerManager]: Found player for index \(index)")
            // Remove time observer
            if let token = timeObserverTokens[index] {
                print(" [VideoPlayerManager]: Removing time observer for index \(index)")
                player.removeTimeObserver(token)
                timeObserverTokens.removeValue(forKey: index)
            }
            
            // Cleanup player
            print(" [VideoPlayerManager]: Pausing player \(index)")
            player.pause()
            print(" [VideoPlayerManager]: Clearing items for player \(index)")
            player.replaceCurrentItem(with: nil)
            player.removeAllItems()
        } else {
            print(" [VideoPlayerManager]: No player found for index \(index)")
        }
        
        players.removeValue(forKey: index)
        
        if currentIndex == index {
            print(" [VideoPlayerManager]: Clearing current index \(index)")
            currentIndex = nil
        }
        
        print(" [VideoPlayerManager]: END Unregistering player for index: \(index)")
        print(" [VideoPlayerManager]: Remaining active players: \(players.keys.sorted())")
    }
    
    func pauseAllExcept(index: Int) {
        print(" [VideoPlayerManager]: START PauseAllExcept index: \(index)")
        print(" [VideoPlayerManager]: Current active players: \(players.keys.sorted())")
        print(" [VideoPlayerManager]: Current index before: \(String(describing: currentIndex))")
        
        // First, cleanup all players except the target index
        let playersToRemove = players.keys.filter { $0 != index }
        for playerIndex in playersToRemove {
            print(" [VideoPlayerManager]: Force cleaning up player \(playerIndex)")
            unregister(index: playerIndex)
        }
        
        // Now handle the current player
        if let player = players[index] {
            print(" [VideoPlayerManager]: Setting up current player \(index)")
            player.seek(to: .zero)
            player.play()
            currentIndex = index
        }
        
        print(" [VideoPlayerManager]: END PauseAllExcept - Current index after: \(String(describing: currentIndex))")
        print(" [VideoPlayerManager]: Final active players: \(players.keys.sorted())")
    }
    
    func cleanup() {
        print(" [VideoPlayerManager]: Cleaning up all players")
        
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