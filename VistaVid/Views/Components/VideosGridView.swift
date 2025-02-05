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
    }
}

struct VideoThumbnailView: View {
    let video: Video
    
    var body: some View {
        // Placeholder for video thumbnail
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(9/16, contentMode: .fit)
            
            VStack {
                if let thumbnailUrl = video.thumbnailUrl {
                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Image(systemName: "play.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }
        }
        .cornerRadius(8)
    }
}
