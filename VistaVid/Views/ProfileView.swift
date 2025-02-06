import SwiftUI
import FirebaseAuth
import AVKit

struct ProfileView: View {
    let model: AuthenticationViewModel
    @StateObject private var videoModel = VideoViewModel()
    
    // MARK: - Properties
    @State private var showingSettings = false
    @State private var userVideos: [Video] = []
    @State private var isLoadingVideos = false
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    ProfileHeaderSection(model: model)
                        .padding(.horizontal)
                    
                    // Stats Section
                    StatsSection(videosCount: userVideos.count)
                        .padding(.horizontal)
                    
                    // Videos Grid
                    VideosGridSection(videos: userVideos, videoModel: videoModel)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(model: model)) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                    }
                }
            }
            .task {
                await loadUserVideos()
            }
            .refreshable {
                await loadUserVideos()
            }
        }
    }
    
    private func loadUserVideos() async {
        guard let userId = model.currentUser?.id else { return }
        
        isLoadingVideos = true
        defer { isLoadingVideos = false }
        
        do {
            userVideos = try await videoModel.fetchUserVideos(userId: userId)
        } catch {
            print("❌ Error loading user videos: \(error)")
            self.error = error
        }
    }
}

// MARK: - Profile Header Section
private struct ProfileHeaderSection: View {
    let model: AuthenticationViewModel
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUpdatingProfilePic = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            // Profile Image
            ProfileImageButton(
                profilePicUrl: model.currentUser?.profilePicUrl,
                isUpdatingProfilePic: $isUpdatingProfilePic,
                showingImagePicker: $showingImagePicker
            )
            .frame(width: 100, height: 100)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.currentUser?.username ?? "Username")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(model.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            guard let image = newValue else { return }
            uploadProfilePicture(image)
        }
    }
    
    private func uploadProfilePicture(_ image: UIImage) {
        print("📸 Starting profile picture upload...")
        isUpdatingProfilePic = true
        
        Task {
            do {
                try await model.updateProfilePicture(image)
                print("✅ Profile picture updated successfully")
            } catch {
                print("❌ Failed to update profile picture: \(error)")
            }
            selectedImage = nil
            isUpdatingProfilePic = false
        }
    }
}

// MARK: - Stats Section
private struct StatsSection: View {
    let videosCount: Int
    
    var body: some View {
        HStack(spacing: 30) {
            StatItem(count: "\(videosCount)", title: "Posts")
            StatItem(count: "0", title: "Followers")
            StatItem(count: "0", title: "Following")
        }
    }
}

private struct StatItem: View {
    let count: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Videos Grid Section
private struct VideosGridSection: View {
    let videos: [Video]
    @StateObject private var videoManager = VideoPlayerManager()
    @ObservedObject var videoModel: VideoViewModel
    
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
    
    var body: some View {
        Group {
            if let thumbnailUrl = video.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure(_):
                        Color.gray
                            .overlay(
                                Image(systemName: "video.slash")
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        Color.gray
                    }
                }
            } else {
                Color.gray
                    .overlay(
                        Image(systemName: "video")
                            .foregroundColor(.white)
                    )
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