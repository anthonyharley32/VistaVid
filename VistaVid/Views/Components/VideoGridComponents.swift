import SwiftUI
import AVKit

// MARK: - Videos Grid Section
struct VideosGridSection: View {
    let videos: [Video]
    let videoModel: VideoViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<videos.count, id: \.self) { index in
                NavigationLink(destination: VideoView(video: videos[index])) {
                    VideoThumbnail(video: videos[index])
                }
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

// MARK: - Video Thumbnail
private struct VideoThumbnail: View {
    let video: Video
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(9/16, contentMode: .fill)
            }
        }
        .clipped()
        .task {
            if let url = video.url {
                let asset = AVURLAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                do {
                    let cgImage = try await imageGenerator.image(at: .zero).image
                    thumbnail = UIImage(cgImage: cgImage)
                } catch {
                    print("Error generating thumbnail: \(error)")
                }
            }
        }
    }
}
