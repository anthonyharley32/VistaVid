import SwiftUI
import AVKit
import FirebaseAuth

// MARK: - Main View
struct VideoCardView: View {
    let video: Video
    @Binding var isCurrentlyPlaying: Bool
    let onDoubleTap: (CGPoint) -> Void
    let onProfileTap: ((String) -> Void)?
    
    @StateObject private var videoModel = VideoViewModel()
    @State private var isLiked = false
    @State private var localLikesCount: Int
    @State private var localCommentsCount: Int
    @State private var showComments = false
    
    init(video: Video, isCurrentlyPlaying: Binding<Bool>, onDoubleTap: @escaping (CGPoint) -> Void, onProfileTap: ((String) -> Void)?) {
        self.video = video
        self._isCurrentlyPlaying = isCurrentlyPlaying
        self.onDoubleTap = onDoubleTap
        self.onProfileTap = onProfileTap
        self._localLikesCount = State(initialValue: video.likesCount)
        self._localCommentsCount = State(initialValue: video.commentsCount)
    }
    
    var body: some View {
        VideoCardContent(
            video: video,
            isCurrentlyPlaying: $isCurrentlyPlaying,
            isLiked: $isLiked,
            localLikesCount: $localLikesCount,
            localCommentsCount: $localCommentsCount,
            showComments: $showComments,
            onDoubleTap: onDoubleTap,
            onProfileTap: onProfileTap,
            handleLike: handleLike
        )
        .task {
            await checkLikeStatus()
        }
    }
    
    private func checkLikeStatus() async {
        do {
            isLiked = try await videoModel.checkLikeStatus(for: video)
            print("✅ Successfully checked like status: \(isLiked)")
        } catch {
            print("❌ Error checking like status: \(error)")
        }
    }
    
    private func handleLike() {
        Task {
            do {
                try await videoModel.toggleLike(for: video)
                isLiked.toggle()
                localLikesCount += isLiked ? 1 : -1
                print("✅ Successfully toggled like")
            } catch {
                print("❌ Error toggling like: \(error)")
            }
        }
    }
}

// MARK: - Content Components
private struct VideoCardContent: View {
    let video: Video
    @Binding var isCurrentlyPlaying: Bool
    @Binding var isLiked: Bool
    @Binding var localLikesCount: Int
    @Binding var localCommentsCount: Int
    @Binding var showComments: Bool
    let onDoubleTap: (CGPoint) -> Void
    let onProfileTap: ((String) -> Void)?
    let handleLike: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VideoPlayerContainer(video: video, isCurrentlyPlaying: $isCurrentlyPlaying, geometry: geometry)
                VideoOverlayContainer(
                    video: video,
                    isLiked: $isLiked,
                    localLikesCount: $localLikesCount,
                    localCommentsCount: $localCommentsCount,
                    showComments: $showComments,
                    onDoubleTap: onDoubleTap,
                    onProfileTap: onProfileTap,
                    handleLike: handleLike
                )
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .sheet(isPresented: $showComments) {
            CommentView(video: video, onCommentAdded: { 
                localCommentsCount += 1
            })
        }
    }
}

private struct VideoPlayerContainer: View {
    let video: Video
    @Binding var isCurrentlyPlaying: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        if let url = URL(string: video.videoUrl) {
            VideoPlayerView(url: url, shouldPlay: isCurrentlyPlaying, video: video)
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}

private struct VideoOverlayContainer: View {
    let video: Video
    @Binding var isLiked: Bool
    @Binding var localLikesCount: Int
    @Binding var localCommentsCount: Int
    @Binding var showComments: Bool
    let onDoubleTap: (CGPoint) -> Void
    let onProfileTap: ((String) -> Void)?
    let handleLike: () -> Void
    
    var body: some View {
        ZStack {
            gradientOverlay
            doubleTapLayer
            contentLayer
        }
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                .clear,
                .black.opacity(0.2),
                .black.opacity(0.6)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var doubleTapLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                onDoubleTap(location)
                if !isLiked {
                    handleLike()
                }
            }
    }
    
    private var contentLayer: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 16) {
                VideoInfoView(video: video, onProfileTap: onProfileTap)
                Spacer()
                InteractionButtonsStack(
                    isLiked: isLiked,
                    localLikesCount: localLikesCount,
                    localCommentsCount: localCommentsCount,
                    sharesCount: video.sharesCount,
                    showComments: $showComments,
                    handleLike: handleLike
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }
}

private struct VideoInfoView: View {
    let video: Video
    let onProfileTap: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(video.description)
                .font(.subheadline)
                .lineLimit(2)
            
            if let user = video.user {
                CreatorInfoView(user: user, onProfileTap: onProfileTap)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

private struct CreatorInfoView: View {
    let user: User
    let onProfileTap: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            let _ = print("👤 [CreatorInfoView] Rendering for user: \(user.username), id: \(user.id)")
            ProfileNavigationLink(user: user)
            
            Button {
                let _ = print("👆 [CreatorInfoView] Username button tapped for: \(user.username)")
                onProfileTap?(user.id)
            } label: {
                Text("@\(user.username)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct ProfileNavigationLink: View {
    let user: User
    
    var body: some View {
        let _ = print("🔗 [ProfileNavigationLink] Creating navigation link for user: \(user.username)")
        let _ = print("🔍 [ProfileNavigationLink] Current user ID: \(Auth.auth().currentUser?.uid ?? "nil")")
        let _ = print("🎯 [ProfileNavigationLink] Target user ID: \(user.id)")
        let _ = print("🖼️ [ProfileNavigationLink] Profile picture URL: \(user.profilePicUrl ?? "nil")")
        
        NavigationLink {
            Group {
                if user.id == Auth.auth().currentUser?.uid {
                    let _ = print("🏠 [ProfileNavigationLink] Navigating to own profile")
                    ProfileView(user: user, authModel: AuthenticationViewModel())
                } else {
                    let _ = print("👥 [ProfileNavigationLink] Navigating to user profile")
                    UserProfileView(user: user)
                }
            }
        } label: {
            AsyncImage(url: URL(string: user.profilePicUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1))
        }
        .simultaneousGesture(TapGesture().onEnded {
            print("📸 [ProfileNavigationLink] Profile image tapped and navigation triggered")
        })
    }
}

private struct InteractionButtonsStack: View {
    let isLiked: Bool
    let localLikesCount: Int
    let localCommentsCount: Int
    let sharesCount: Int
    @Binding var showComments: Bool
    let handleLike: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Like Button
            Button {
                handleLike()
            } label: {
                InteractionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    count: localLikesCount,
                    tint: isLiked ? .red : .white
                )
            }
            
            // Comment Button
            Button {
                showComments = true
            } label: {
                InteractionButton(
                    icon: "bubble.right.fill",
                    count: localCommentsCount,
                    tint: .white
                )
            }
            
            // Share Button
            InteractionButton(
                icon: "arrowshape.turn.up.right.fill",
                count: sharesCount,
                tint: .white
            )
        }
        .foregroundStyle(.white)
    }
}

private struct InteractionButton: View {
    let icon: String
    let count: Int
    let tint: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            Text("\(count)")
                .font(.caption)
                .bold()
                .foregroundStyle(.white)
        }
    }
} 