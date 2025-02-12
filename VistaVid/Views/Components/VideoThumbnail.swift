import SwiftUI
import FirebaseAuth

struct VideoThumbnail: View {
    let video: Video?
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                }
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white.opacity(0.6))
                        if let video = video {
                            Text("❤️ \(video.interactionCounts.likes)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            if let video = video,
               video.creatorId == Auth.auth().currentUser?.uid,
               onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Video", systemImage: "trash")
                }
            }
        }
        .alert("Delete Video", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this video? This action cannot be undone.")
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let video = video else { return }
        isLoading = true
        thumbnail = await ThumbnailGenerator.shared.getThumbnail(for: video)
        isLoading = false
    }
}

#Preview {
    VideoThumbnail(video: nil, onTap: nil, onDelete: nil)
        .frame(width: 150)
        .preferredColorScheme(.dark)
} 