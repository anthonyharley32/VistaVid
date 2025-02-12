import SwiftUI
import AVKit

struct VideoCardView: View {
    let video: Video
    @Binding var isCurrentlyPlaying: Bool
    let onDoubleTap: (CGPoint) -> Void
    let onProfileTap: ((String) -> Void)?
    
    var body: some View {
        ZStack {
            if let url = URL(string: video.videoUrl) {
                VideoPlayerView(url: url, shouldPlay: isCurrentlyPlaying)
            }
            
            // Double tap gesture for like
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { location in
                    onDoubleTap(location)
                }
            
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Video info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                        Text(video.description)
                            .font(.subheadline)
                        
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
                    .shadow(radius: 4)
                    
                    Spacer()
                    
                    // Interaction buttons
                    VStack(spacing: 20) {
                        Text("❤️ \(video.likesCount)")
                        Text("💬 \(video.commentsCount)")
                        Text("↗️ \(video.sharesCount)")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                }
                .padding()
            }
        }
        .background(Color.black)
    }
} 