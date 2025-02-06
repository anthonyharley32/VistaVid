import SwiftUI
import FirebaseAuth
import AVKit

struct ProfileView: View {
    @StateObject var videoModel = VideoViewModel()
    @State private var userVideos: [Video] = []
    @State private var showingSettings = false
    let user: User
    let authModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Profile Header
                    HStack(alignment: .center, spacing: 15) {
                        CircularProfileImage(user: user, size: 90)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("@\(user.username)")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 25) {
                                StatItem(value: "\(userVideos.count)", title: "Posts")
                                StatItem(value: "0", title: "Followers")
                                StatItem(value: "0", title: "Following")
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                    
                    Text("Bio coming soon")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Videos Grid
                    VideosGridSection(videos: userVideos, videoModel: videoModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(model: authModel)) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                    }
                }
            }
        }
        .task {
            if let videos = try? await videoModel.fetchUserVideos(userId: user.id) {
                userVideos = videos
            }
        }
    }
}

private struct StatItem: View {
    let value: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Stats Section
private struct StatsSection: View {
    let videosCount: Int
    
    var body: some View {
        HStack(spacing: 30) {
            StatItem(value: "\(videosCount)", title: "Posts")
            StatItem(value: "0", title: "Followers")
            StatItem(value: "0", title: "Following")
        }
    }
}

// MARK: - Videos Grid Section
private struct VideosGridSection: View {
    let videos: [Video]
    let videoModel: VideoViewModel
    @StateObject private var videoManager = VideoPlayerManager()
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<videos.count, id: \.self) { index in
                NavigationLink(destination: VideoPlayerView(video: videos[index], index: index, videoManager: videoManager, isVisible: true)) {
                    VideoThumbnail(video: videos[index])
                }
            }
        }
    }
}

// MARK: - Video Thumbnail
private struct VideoThumbnail: View {
    let video: Video
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width/3, height: UIScreen.main.bounds.width/2)
                    .clipped()
            } else {
                Color.gray
                    .overlay(
                        Image(systemName: "video")
                            .foregroundColor(.white)
                    )
                    .task {
                        if let url = video.url {
                            do {
                                thumbnail = try await VideoViewModel().generateThumbnail(for: url)
                            } catch {
                                print("❌ Failed to generate thumbnail: \(error)")
                            }
                        }
                    }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}

// MARK: - Profile Image Button
struct ProfileImageButton: View {
    let profilePicUrl: String?
    @Binding var isUpdatingProfilePic: Bool
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        Button(action: { showingImagePicker = true }) {
            ZStack {
                if let profilePicUrl = profilePicUrl,
                   let url = URL(string: profilePicUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure(_):
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                
                // Edit overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(4)
                
                if isUpdatingProfilePic {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Prevents button styling from affecting touch area
        .contentShape(Circle()) // Explicitly set the touch area to the circle
    }
}

struct CircularProfileImage: View {
    let user: User
    let size: CGFloat
    
    var body: some View {
        AsyncImage(url: URL(string: user.profilePicUrl ?? "")) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure(_):
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            @unknown default:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}