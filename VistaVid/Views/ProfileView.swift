import SwiftUI
import FirebaseAuth
import AVKit

struct ProfileView: View {
    @StateObject var videoModel = VideoViewModel()
    @State private var userVideos: [Video] = []
    @State private var selectedTab = 0
    let user: User
    let authModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Profile Header
                    VStack(spacing: 16) {
                        CircularProfileImage(user: user, size: 100)
                        
                        VStack(spacing: 6) {
                            Text("@\(user.username)")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Bio coming soon")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        // Stats Row
                        HStack {
                            Spacer()
                            StatItem(value: "\(userVideos.count)", title: "Posts")
                                .frame(width: 80)
                            StatItem(value: "0", title: "Followers")
                                .frame(width: 80)
                            StatItem(value: "0", title: "Following")
                                .frame(width: 80)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Tab Selector
                    HStack(spacing: 0) {
                        ForEach(["Posts", "Likes"], id: \.self) { tab in
                            Button(action: { 
                                withAnimation { selectedTab = tab == "Posts" ? 0 : 1 }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: tab == "Posts" ? "grid" : "heart")
                                        .font(.system(size: 20))
                                    Rectangle()
                                        .fill(selectedTab == (tab == "Posts" ? 0 : 1) ? Color.primary : Color.clear)
                                        .frame(height: 2)
                                }
                                .foregroundColor(selectedTab == (tab == "Posts" ? 0 : 1) ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Content
                    if selectedTab == 0 {
                        if userVideos.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 40)
                                Text("No posts yet")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Videos you post will appear here")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                        } else {
                            VideosGridSection(videos: userVideos, videoModel: videoModel)
                                .padding(.top, 2)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                            Text("No likes yet")
                                .font(.system(size: 16, weight: .medium))
                            Text("Videos you like will appear here")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(model: authModel)) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
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
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
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