import SwiftUI
import AVKit

// MARK: - Videos Grid Section
struct VideosGridSection: View {
    let videos: [Video]
    let onVideoTap: (Video) -> Void
    let onDelete: ((Video) -> Void)?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 1),
            GridItem(.flexible(), spacing: 1),
            GridItem(.flexible(), spacing: 1)
        ], spacing: 1) {
            ForEach(videos) { video in
                VideoThumbnail(
                    video: video,
                    onTap: { onVideoTap(video) },
                    onDelete: onDelete != nil ? { onDelete?(video) } : nil
                )
            }
        }
    }
}

// Simple Video View
struct VideoView: View {
    let video: Video
    
    var body: some View {
        if let url = video.url {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
        } else {
            ContentUnavailableView("Video Unavailable",
                systemImage: "video.slash",
                description: Text("This video cannot be played"))
        }
    }
}
