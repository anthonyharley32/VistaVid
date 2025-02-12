import SwiftUI
import FirebaseAuth
import AVKit

struct ProfileView: View {
    @StateObject var videoModel = VideoViewModel()
    @State private var userVideos: [Video] = []
    @State private var likedVideos: [Video] = []
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
                                Image(systemName: "play.fill")
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
                            VideosGridSection(
                                videos: userVideos,
                                onVideoTap: { video in
                                    // Handle video tap
                                },
                                onDelete: { video in
                                    // Handle delete
                                }
                            )
                                .padding(.top, 2)
                        }
                    } else {
                        if likedVideos.isEmpty {
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
                        } else {
                            VideosGridSection(
                                videos: likedVideos,
                                onVideoTap: { video in
                                    // Handle video tap
                                },
                                onDelete: { video in
                                    // Handle delete
                                }
                            )
                                .padding(.top, 2)
                        }
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
            await loadContent()
        }
    }
    
    private func loadContent() async {
        // Load user videos
        print("🎥 Starting to fetch user videos for: \(user.id)")
        if let videos = try? await videoModel.fetchUserVideos(userId: user.id) {
            print("📊 User videos data received: \(videos.count) videos")
            userVideos = videos
            print("✅ Successfully updated userVideos state with \(userVideos.count) videos")
        } else {
            print("❌ Failed to fetch user videos")
        }
        
        // Load liked videos
        print("❤️ Starting to fetch liked videos for user: \(user.id)")
        do {
            let liked = try await videoModel.fetchLikedVideos(userId: user.id)
            print("📊 Liked videos data received: \(liked.count) videos")
            print("🔍 First few liked video IDs: \(liked.prefix(3).map { $0.id }.joined(separator: ", "))")
            likedVideos = liked
            print("✅ Successfully updated likedVideos state with \(likedVideos.count) videos")
        } catch {
            print("❌ Error fetching liked videos: \(error.localizedDescription)")
            print("🔬 Detailed error: \(error)")
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

struct CircularProfileImage: View {
    let user: User
    let size: CGFloat
    
    var body: some View {
        Group {
            if let urlString = user.profilePicUrl,
               let url = URL(string: urlString) {
                // Debug log for URL validation
                let _ = print("🖼️ [Profile]: Loading image from URL: \(urlString)")
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                    case .failure(let error):
                        // Debug log for loading failures
                        let _ = print("❌ [Profile]: Failed to load image: \(error.localizedDescription)")
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: size, height: size)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: size, height: size)
                    }
                }
            } else {
                // Debug log for invalid URL
                let _ = print("⚠️ [Profile]: Invalid profile image URL: \(user.profilePicUrl ?? "nil")")
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: size, height: size)
            }
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

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