import SwiftUI
import AVKit

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
        GeometryReader { geometry in
            ZStack {
                // Single Video Player with optimized layout
                if let url = URL(string: video.videoUrl) {
                    VideoPlayerView(url: url, shouldPlay: isCurrentlyPlaying, video: video)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .background(Color.black)
                }
                
                // Gradient overlay for better text visibility
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .black.opacity(0.2),
                        .black.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Double tap gesture for like
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { location in
                        onDoubleTap(location)
                        if !isLiked {
                            handleLike()
                        }
                    }
                
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 16) {
                        // Video info
                        VStack(alignment: .leading, spacing: 6) {
                            Text(video.description)
                                .font(.subheadline)
                                .lineLimit(2)
                            
                            // Creator info
                            if let user = video.user {
                                Button {
                                    onProfileTap?(user.id)
                                } label: {
                                    HStack {
                                        Text("@\(user.username)")
                                            .font(.subheadline)
                                            .bold()
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Spacer()
                        
                        // Interaction buttons
                        VStack(spacing: 20) {
                            Button {
                                handleLike()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 24))
                                        .foregroundStyle(isLiked ? .red : .white)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    Text("\(localLikesCount)")
                                        .font(.caption)
                                        .bold()
                                }
                            }
                            Button {
                                showComments = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "bubble.right.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    Text("\(localCommentsCount)")
                                        .font(.caption)
                                        .bold()
                                }
                            }
                            VStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                Text("\(video.sharesCount)")
                                    .font(.caption)
                                    .bold()
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110) // Increased bottom padding to raise content higher
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .sheet(isPresented: $showComments) {
            CommentView(video: video, onCommentAdded: { 
                localCommentsCount += 1
            })
        }
        .task {
            // Check if user has liked this video
            do {
                isLiked = try await videoModel.checkLikeStatus(for: video)
                print("✅ Successfully checked like status: \(isLiked)")
            } catch {
                print("❌ Error checking like status: \(error)")
            }
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