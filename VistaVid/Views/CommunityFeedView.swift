import SwiftUI

@Observable @MainActor
final class CommunityFeedViewModel {
    // MARK: - Properties
    var videos: [Video] = []
    var error: String?
    var isLoading = false
    let communityId: String
    
    init(communityId: String) {
        self.communityId = communityId
        print("🎬 [CommunityFeedViewModel] Initialized for community: \(communityId)")
        Task {
            await loadVideos()
        }
    }
    
    func loadVideos() async {
        print("🎬 [CommunityFeedViewModel] Loading videos for community: \(communityId)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let videoModel = VideoViewModel()
            videos = try await videoModel.fetchCommunityVideos(communityId: communityId)
            print("✅ [CommunityFeedViewModel] Loaded \(videos.count) videos")
        } catch {
            print("❌ [CommunityFeedViewModel] Error loading videos: \(error)")
            self.error = error.localizedDescription
        }
    }
}

struct CommunityFeedView: View {
    let model: CommunityFeedViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if let error = model.error {
                VStack {
                    Text("Error loading videos")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                    Button("Retry") {
                        Task { await model.loadVideos() }
                    }
                }
            } else if model.videos.isEmpty {
                Text("No videos in this community yet")
                    .foregroundColor(.secondary)
            } else {
                VideoFeedView(
                    videos: model.videos,
                    startingIndex: 0,
                    title: "Community Videos",
                    onClose: { dismiss() }
                )
            }
        }
    }
}
