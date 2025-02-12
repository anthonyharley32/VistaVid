import SwiftUI
import FirebaseAuth
import AVKit
import FirebaseFirestore

struct UserProfileView: View {
    @StateObject private var videoModel = VideoViewModel()
    @State private var followModel = FollowViewModel()
    @State private var messageModel = MessageViewModel()
    @State private var userVideos: [Video] = []
    @State private var likedVideos: [Video] = []
    @State private var navigateToChat = false
    @State private var selectedTab = 0
    @State private var loadedUser: User?
    @State private var isLoading = true
    @State private var selectedVideo: Video?
    @State private var showVideoPlayer = false
    
    let user: User?
    let userId: String?
    
    init(user: User) {
        self.user = user
        self.userId = nil
    }
    
    init(userId: String) {
        self.user = nil
        self.userId = userId
    }
    
    private var displayUser: User? {
        user ?? loadedUser
    }
    
    var body: some View {
        Group {
            if let user = displayUser {
                userProfileContent(user: user)
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("User Not Found",
                    systemImage: "person.slash",
                    description: Text("This user could not be found"))
            }
        }
        .task {
            if let userId = userId {
                await loadUser(userId: userId)
            } else if let user = user {
                // Only load content directly if we have a user already
                await loadContent()
            }
        }
    }
    
    private func loadUser(userId: String) async {
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let userData = document.data(),
               let user = User.fromFirestore(userData, id: userId) {
                loadedUser = user
                // Now that we have the user, load their content
                await loadContent()
            }
        } catch {
            print("❌ Error loading user: \(error)")
        }
        
        isLoading = false
    }
    
    @ViewBuilder
    private func userProfileContent(user: User) -> some View {
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
                        StatItem(value: "\(followModel.followingCount)", title: "Following")
                        StatItem(value: "\(followModel.followersCount)", title: "Followers")
                    }
                    .padding(.top, 5)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                do {
                                    try await followModel.toggleFollow(for: user.id)
                                } catch {
                                    print("❌ Error toggling follow: \(error.localizedDescription)")
                                }
                            }
                        }) {
                            Text(followModel.isFollowing ? "Following" : "Follow")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(followModel.isFollowing ? .secondary : .white)
                                .frame(width: 120, height: 36)
                                .background(followModel.isFollowing ? Color.gray.opacity(0.1) : Color.blue)
                                .cornerRadius(18)
                        }
                        
                        Button(action: {
                            navigateToChat = true
                        }) {
                            Image(systemName: "message")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(18)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.top, 20)
                
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
                .padding(.top, 20)
                
                // Videos Grid
                if selectedTab == 0 {
                    if userVideos.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                            Text("No posts yet")
                                .font(.system(size: 16, weight: .medium))
                            Text("Videos will appear here")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    } else {
                        VideosGridSection(
                            videos: userVideos,
                            onVideoTap: { video in
                                selectedVideo = video
                                showVideoPlayer = true
                            },
                            onDelete: nil
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
                            Text("Liked videos will appear here")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    } else {
                        VideosGridSection(
                            videos: likedVideos,
                            onVideoTap: { video in
                                selectedVideo = video
                                showVideoPlayer = true
                            },
                            onDelete: nil
                        )
                        .padding(.top, 2)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("@\(user.username)")
        .navigationDestination(isPresented: $navigateToChat) {
            ChatView(recipient: user)
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let video = selectedVideo {
                VideoFeedView(
                    videos: selectedTab == 0 ? userVideos : likedVideos,
                    startingIndex: (selectedTab == 0 ? userVideos : likedVideos).firstIndex(of: video) ?? 0
                )
            }
        }
        .onAppear {
            print("👤 UserProfileView appeared for user: \(user.username)")
            Task {
                followModel.startObservingFollowStatus(for: user.id)
            }
        }
        .onDisappear {
            followModel.cleanup()
        }
    }
    
    private func loadContent() async {
        print("📥 [UserProfileView] Starting loadContent")
        guard let user = displayUser else {
            print("❌ [UserProfileView] No display user available")
            return
        }
        print("👤 [UserProfileView] Loading content for user: \(user.username) (ID: \(user.id))")
        
        // Load user videos
        print("🎥 [UserProfileView] Starting to fetch user videos")
        if let videos = try? await videoModel.fetchUserVideos(userId: user.id) {
            print("📊 [UserProfileView] User videos received: \(videos.count) videos")
            await MainActor.run {
                userVideos = videos
            }
            print("✅ [UserProfileView] Updated userVideos state with \(videos.count) videos")
        } else {
            print("❌ [UserProfileView] Failed to fetch user videos")
        }
        
        // Load liked videos
        print("❤️ [UserProfileView] Starting to fetch liked videos")
        do {
            let liked = try await videoModel.fetchLikedVideos(userId: user.id)
            print("📊 [UserProfileView] Liked videos received: \(liked.count) videos")
            await MainActor.run {
                likedVideos = liked
            }
            print("✅ [UserProfileView] Updated likedVideos state with \(liked.count) videos")
        } catch {
            print("❌ [UserProfileView] Error fetching liked videos: \(error.localizedDescription)")
        }
    }
}

// MARK: - DM View
private struct DMView: View {
    let recipient: User
    let messageModel: MessageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messageModel.messages) { message in
                            MessageBubble(message: message, isFromCurrentUser: message.senderId == Auth.auth().currentUser?.uid)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Message input
                HStack {
                    TextField("Message...", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)
                    
                    Button(action: {
                        Task {
                            isLoading = true
                            do {
                                try await messageModel.sendMessage(messageText, to: recipient.id)
                                messageText = ""
                            } catch {
                                print("❌ Error sending message: \(error.localizedDescription)")
                            }
                            isLoading = false
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(messageText.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Chat with @\(recipient.username)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(16)
            
            if !isFromCurrentUser { Spacer() }
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
