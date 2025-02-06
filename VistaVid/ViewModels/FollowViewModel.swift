import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable final class FollowViewModel {
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var followsListener: ListenerRegistration?
    private var followersListener: ListenerRegistration?
    
    var isFollowing = false {
        didSet {
            print("👥 Follow state changed: \(isFollowing)")
        }
    }
    var followersCount = 0
    var followingCount = 0
    private var isProcessing = false
    
    // MARK: - Initialization
    init() {
        print("📱 FollowViewModel initialized")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    func startObservingFollowStatus(for userId: String) {
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
                
                self?.isFollowing = !(snapshot?.documents.isEmpty ?? true)
            }
        
        // Listen for followers count
        followersListener = db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error observing followers: \(error.localizedDescription)")
                    return
                }
                
                self?.followersCount = snapshot?.documents.count ?? 0
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
            print("✅ Successfully unfollowed user: \(userId)")
        } else {
            // Follow
            let follow = Follow(id: followId, followerId: currentUserId, followingId: userId)
            try await db.collection("follows").document(followId).setData(follow.toDictionary())
            print("✅ Successfully followed user: \(userId)")
        }
    }
    
    func cleanup() {
        followsListener?.remove()
        followersListener?.remove()
    }
}
