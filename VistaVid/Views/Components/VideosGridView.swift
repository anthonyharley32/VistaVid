import SwiftUI

struct VideosGridView: View {
    let videos: [Video]
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(videos) { video in
                VideoThumbnailView(video: video)
            }
        }
        .task {
            // Preload thumbnails for all videos in the grid
            await ThumbnailManager.shared.preloadThumbnails(for: videos)
        }
    }
}

struct VideoThumbnailView: View {
    let video: Video
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(9/16, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .cornerRadius(8)
        .task {
            thumbnail = await ThumbnailManager.shared.thumbnail(for: video)
        }
    }
}
