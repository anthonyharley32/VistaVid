import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommentView: View {
    let video: Video
    let onCommentAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var videoModel = VideoViewModel()
    @State private var comments: [(id: String, userId: String, text: String, createdAt: Date)] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var users: [String: User] = [:]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments, id: \.id) { comment in
                            CommentRow(
                                comment: comment,
                                user: users[comment.userId]
                            )
                        }
                    }
                    .padding()
                }
                
                // Comment input
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField("Add a comment...", text: $newComment)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.send)
                            .onSubmit {
                                submitComment()
                            }
                        
                        Button {
                            submitComment()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(newComment.isEmpty ? .gray : .blue)
                        }
                        .disabled(newComment.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadComments()
        }
    }
    
    private func submitComment() {
        guard !newComment.isEmpty else { return }
        
        let commentText = newComment
        newComment = "" // Clear input immediately for better UX
        
        Task {
            do {
                try await videoModel.addComment(to: video, text: commentText)
                await loadComments() // Reload comments to show the new one
                onCommentAdded() // Call the callback when comment is added
                print("✅ Successfully added comment")
            } catch {
                print("❌ Error adding comment: \(error)")
                self.error = error
                // TODO: Show error alert
            }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            comments = try await videoModel.fetchComments(for: video)
            
            // Fetch user data for each comment
            for comment in comments {
                if users[comment.userId] == nil {
                    if let user = try? await fetchUser(userId: comment.userId) {
                        users[comment.userId] = user
                    }
                }
            }
            
            print("✅ Successfully loaded \(comments.count) comments")
        } catch {
            print("❌ Error loading comments: \(error)")
            self.error = error
        }
    }
    
    private func fetchUser(userId: String) async throws -> User {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId)
        let document = try await docRef.getDocument()
        
        guard let data = document.data(),
              let user = User.fromFirestore(data, id: document.documentID) else {
            throw NSError(domain: "CommentView", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        return user
    }
}

struct CommentRow: View {
    let comment: (id: String, userId: String, text: String, createdAt: Date)
    let user: User?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar
            if let user = user {
                CircularProfileImage(user: user, size: 40)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user?.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(timeAgo(from: comment.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(comment.text)
                    .font(.subheadline)
            }
            
            Spacer()
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 