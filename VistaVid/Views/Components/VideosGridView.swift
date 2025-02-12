import SwiftUI
import AVFoundation

struct VideosGridView: View {
    let videos: [Video]
    
    private let columns = [
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

private struct VideoThumbnailView: View {
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
            await generateThumbnail()
        }
    }
    
    private func generateThumbnail() async {
        guard let url = video.url else { return }
        
        do {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            let cgImage = try await generator.image(at: .zero).image
            await MainActor.run {
                thumbnail = UIImage(cgImage: cgImage)
            }
        } catch {
            print("📱 Error generating thumbnail: \(error)")
        }
    }
}

#Preview {
    VideosGridView(videos: [])
}
