import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

final class FollowViewModel: ObservableObject {
    // MARK: - Properties
    private let db: Firestore
    private var followsListener: ListenerRegistration?
    private var followersListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?
    
    @Published var isFollowing = false {
        didSet {
            print("👥 Follow state changed: \(isFollowing)")
        }
    }
    @Published var followersCount = 0
    @Published var followingCount = 0
    private var isProcessing = false
    
    // MARK: - Initialization
    init() {
        self.db = FirestoreService.shared.db
        print("📱 FollowViewModel initialized")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    func startObservingFollowStatus(for userId: String) {
        print("🔄 [FollowViewModel] Starting observation for user: \(userId)")
        // Clean up existing listeners first
        cleanup()
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen for follow status
        followsListener = db.collection("follows")
            .whereField("followerId", isEqualTo: currentUserId)
            .whereField("followingId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error observing follow status: \(error.localizedDescription)")
                    return
                }
                
                let following = !(snapshot?.documents.isEmpty ?? true)
                print("👥 [FollowViewModel] Follow status updated: \(following)")
                self?.isFollowing = following
            }
        
        // Listen for followers count
        followersListener = db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error observing followers: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("👥 [FollowViewModel] Updated followers count: \(count)")
                self?.followersCount = count
            }
            
        // Listen for following count
        followingListener = db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error observing following: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("👥 [FollowViewModel] Updated following count: \(count)")
                self?.followingCount = count
            }
    }
    
    func toggleFollow(for userId: String) async throws {
        guard !isProcessing else {
            print("⚠️ Follow action already in progress")
            return
        }
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FollowError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let followId = "\(currentUserId)_\(userId)"
        
        if isFollowing {
            // Unfollow
            try await db.collection("follows").document(followId).delete()
            // Update UI immediately
            isFollowing = false
            print("✅ Successfully unfollowed user: \(userId)")
        } else {
            // Check if already following
            let doc = try await db.collection("follows").document(followId).getDocument()
            guard !doc.exists else {
                print("⚠️ Already following user: \(userId)")
                isFollowing = true
                return
            }
            
            // Follow
            let follow = Follow(id: followId, followerId: currentUserId, followingId: userId)
            try await db.collection("follows").document(followId).setData(follow.toDictionary())
            // Update UI immediately
            isFollowing = true
            print("✅ Successfully followed user: \(userId)")
        }
    }
    
    func cleanup() {
        followsListener?.remove()
        followersListener?.remove()
        followingListener?.remove()
    }
}
