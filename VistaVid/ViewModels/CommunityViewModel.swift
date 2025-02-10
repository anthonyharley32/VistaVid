import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable final class CommunityViewModel: ObservableObject {
    // MARK: - Properties
    private(set) var communities: [Community] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    private let db: Firestore
    
    // MARK: - Debug Properties
    private let debug = true
    
    // MARK: - Initializer
    init() {
        self.db = FirestoreService.shared.db
    }
    
    // MARK: - Community Methods
    
    /// Creates a new community
    func createCommunity(
        name: String,
        description: String,
        iconType: String,
        iconEmoji: String?,
        iconImageUrl: String?,
        backgroundColor: String
    ) async throws {
        debugLog("📝 Creating community with name: '\(name)'")
        
        // Ensure the name is properly formatted
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameLowercase = trimmedName.lowercased()
        
        let data: [String: Any] = [
            "name": trimmedName,
            "nameLowercase": nameLowercase,
            "description": description,
            "iconType": iconType,
            "iconEmoji": iconEmoji as Any,
            "iconImageUrl": iconImageUrl as Any,
            "backgroundColor": backgroundColor,
            "createdAt": Timestamp(date: Date()),
            "creatorId": Auth.auth().currentUser?.uid ?? "",
            "membersCount": 1,
            "members": [Auth.auth().currentUser?.uid ?? ""],
            "moderators": [Auth.auth().currentUser?.uid ?? ""],
            "followersCount": 0
        ]
        
        debugLog("📋 Community data:")
        debugLog("  - Name: \(trimmedName)")
        debugLog("  - NameLowercase: \(nameLowercase)")
        debugLog("  - IconType: \(iconType)")
        
        do {
            // First check if a community with this name already exists
            let existingQuery = db.collection("communities")
                .whereField("nameLowercase", isEqualTo: nameLowercase)
            let existingDocs = try await existingQuery.getDocuments()
            
            guard existingDocs.documents.isEmpty else {
                debugLog("❌ Community with this name already exists")
                throw NSError(
                    domain: "Community",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "A community with this name already exists"]
                )
            }
            
            let docRef = try await db.collection("communities").addDocument(data: data)
            debugLog("✅ Community created with ID: \(docRef.documentID)")
        } catch {
            debugLog("❌ Failed to create community: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches all communities
    func fetchCommunities() async {
        debugLog("📚 Fetching communities")
        debugLog("🔐 Current user ID: \(Auth.auth().currentUser?.uid ?? "no user")")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("communities")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            debugLog("📥 Got \(snapshot.documents.count) documents from Firestore")
            
            communities = snapshot.documents.compactMap { document in
                debugLog("🔄 Processing document ID: \(document.documentID)")
                debugLog("📄 Document data: \(document.data())")
                return Community.fromFirestore(document.data(), id: document.documentID)
            }
            
            debugLog("✅ Successfully parsed \(communities.count) communities")
            debugLog("📋 Community IDs: \(communities.map { $0.id })")
            
        } catch {
            debugLog("❌ Error fetching communities: \(error.localizedDescription)")
            debugLog("🔍 Detailed error: \(error)")
            self.error = error
        }
    }
    
    /// Joins a community
    func joinCommunity(_ communityId: String) async throws {
        debugLog("👋 Joining community: \(communityId)")
        
        guard let currentUser = Auth.auth().currentUser else {
            debugLog("❌ No authenticated user found")
            throw NSError(domain: "Community", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            try await db.collection("communities").document(communityId)
                .updateData([
                    "members": FieldValue.arrayUnion([currentUser.uid])
                ])
            
            debugLog("✅ Joined community successfully")
            await fetchCommunities()
            
        } catch {
            debugLog("❌ Error joining community: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Leaves a community
    func leaveCommunity(_ communityId: String) async throws {
        debugLog("👋 Leaving community: \(communityId)")
        
        guard let currentUser = Auth.auth().currentUser else {
            debugLog("❌ No authenticated user found")
            throw NSError(domain: "Community", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            try await db.collection("communities").document(communityId)
                .updateData([
                    "members": FieldValue.arrayRemove([currentUser.uid])
                ])
            
            debugLog("✅ Left community successfully")
            await fetchCommunities()
            
        } catch {
            debugLog("❌ Error leaving community: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Checks if the current user is a member of a community
    func isMember(of communityId: String) -> Bool {
        guard let currentUser = Auth.auth().currentUser,
              let community = communities.first(where: { $0.id == communityId }) else {
            return false
        }
        
        return community.members.contains(currentUser.uid)
    }
    
    /// Checks if the current user is a moderator of a community
    func isModerator(of communityId: String) -> Bool {
        guard let currentUser = Auth.auth().currentUser,
              let community = communities.first(where: { $0.id == communityId }) else {
            return false
        }
        
        return community.moderators.contains(currentUser.uid)
    }
    
    // MARK: - Helper Methods
    
    private func debugLog(_ message: String) {
        if debug {
            print("👥 [Community]: \(message)")
        }
    }
} 