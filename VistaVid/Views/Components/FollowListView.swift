import SwiftUI
import FirebaseFirestore

struct FollowListView: View {
    let userId: String
    let type: FollowType // followers or following
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var isLoading = true
    
    enum FollowType {
        case followers, following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if users.isEmpty {
                    ContentUnavailableView(
                        type == .followers ? "No Followers" : "Not Following Anyone",
                        systemImage: "person.2",
                        description: Text(type == .followers ? "You don't have any followers yet" : "You're not following anyone yet")
                    )
                } else {
                    userList
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadUsers()
        }
    }
    
    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(users) { user in
                    NavigationLink(destination: UserProfileView(user: user)) {
                        HStack(spacing: 12) {
                            CircularProfileImage(user: user, size: 50)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.system(size: 16, weight: .semibold))
                                if let bio = user.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 74)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func loadUsers() async {
        print("📥 [FollowListView] Loading \(type.title.lowercased())")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            let followsRef = db.collection("follows")
            
            // Query follows collection based on type
            let query = type == .followers
                ? followsRef.whereField("followingId", isEqualTo: userId)
                : followsRef.whereField("followerId", isEqualTo: userId)
            
            let snapshot = try await query.getDocuments()
            
            // Get user IDs from follows
            let userIds = snapshot.documents.map { doc -> String in
                let data = doc.data()
                return type == .followers
                    ? data["followerId"] as? String ?? ""
                    : data["followingId"] as? String ?? ""
            }
            
            // Fetch user documents
            var loadedUsers: [User] = []
            for userId in userIds {
                if let userDoc = try await db.collection("users").document(userId).getDocument().data(),
                   let user = User.fromFirestore(userDoc, id: userId) {
                    loadedUsers.append(user)
                }
            }
            
            // Sort by username
            users = loadedUsers.sorted { $0.username < $1.username }
            print("✅ [FollowListView] Loaded \(users.count) users")
        } catch {
            print("❌ [FollowListView] Error loading users: \(error)")
        }
    }
}
