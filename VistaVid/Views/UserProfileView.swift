import SwiftUI
import FirebaseAuth
import AVKit

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var videoModel = VideoViewModel()
    @State private var userVideos: [Video] = []
    let user: User
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Profile Header
                VStack(spacing: 15) {
                    CircularProfileImage(user: user, size: 100)
                    
                    Text(user.username)
                        .font(.system(size: 16, weight: .semibold))
                    
                    // Stats
                    HStack(spacing: 35) {
                        StatItem(value: "\(userVideos.count)", title: "Videos")
                        StatItem(value: "0", title: "Following")
                        StatItem(value: "0", title: "Followers")
                    }
                    .padding(.top, 5)
                }
                .padding(.top, 20)
                
                // Videos Grid
                VideosGridSection(videos: userVideos, videoModel: videoModel)
                    .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            print("👤 UserProfileView appeared for user: \(user.username)")
            Task {
                await loadUserVideos()
            }
        }
    }
    
    private func loadUserVideos() async {
        print("🎥 Fetching videos for user: \(user.id)")
        if let videos = try? await videoModel.fetchUserVideos(userId: user.id) {
            userVideos = videos
            print("✅ Successfully fetched \(videos.count) videos for user: \(user.username)")
        } else {
            print("❌ Failed to fetch videos for user: \(user.username)")
        }
    }
}

private struct StatItem: View {
    let value: String
    let title: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
