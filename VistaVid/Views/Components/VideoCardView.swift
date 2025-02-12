import SwiftUI
import AVKit

struct VideoCardView: View {
    let video: Video
    @Binding var isCurrentlyPlaying: Bool
    let onDoubleTap: (CGPoint) -> Void
    let onProfileTap: ((String) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Background - blurred for edges
                if let url = URL(string: video.videoUrl) {
                    VideoPlayerView(url: url, shouldPlay: isCurrentlyPlaying)
                        .blur(radius: 30)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                // Main Video Player
                if let url = URL(string: video.videoUrl) {
                    VideoPlayerView(url: url, shouldPlay: isCurrentlyPlaying)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
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
                .ignoresSafeArea()
                
                // Double tap gesture for like
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { location in
                        onDoubleTap(location)
                    }
                
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 16) {
                        // Video info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(video.title)
                                .font(.headline)
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
                        VStack(spacing: 24) {
                            VStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                Text("\(video.likesCount)")
                                    .font(.caption)
                                    .bold()
                            }
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.right.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                Text("\(video.commentsCount)")
                                    .font(.caption)
                                    .bold()
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
                    .padding(.bottom, 90) // Add extra padding to clear the tab bar
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
} 