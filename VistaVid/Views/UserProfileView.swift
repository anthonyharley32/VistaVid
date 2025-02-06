import SwiftUI
import FirebaseAuth
import AVKit

struct UserProfileView: View {
    @State private var videoModel = VideoViewModel()
    @State private var followModel = FollowViewModel()
    @State private var messageModel = MessageViewModel()
    @State private var userVideos: [Video] = []
    @State private var navigateToChat = false
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
                
                // Videos Grid
                VideosGridSection(videos: userVideos, videoModel: videoModel)
                    .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("@\(user.username)")
        .navigationDestination(isPresented: $navigateToChat) {
            ChatView(recipient: user)
        }
        .onAppear {
            print("👤 UserProfileView appeared for user: \(user.username)")
            Task {
                await loadUserVideos()
                followModel.startObservingFollowStatus(for: user.id)
            }
        }
        .onDisappear {
            followModel.cleanup()
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
