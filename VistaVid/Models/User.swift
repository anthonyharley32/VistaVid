import Foundation
import FirebaseAuth
import FirebaseFirestore

// User model that matches the Firestore data structure
class User: Identifiable, Codable, Hashable {
    // MARK: - Properties
    let id: String
    var username: String
    let email: String
    let createdAt: Date
    var profilePicUrl: String?
    var isBusiness: Bool
    var selectedAlgorithms: [String]
    var followersCount: Int
    var followingCount: Int
    
    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case username
        case email
        case profilePicUrl
        case createdAt
        case isBusiness
        case selectedAlgorithms
        case followersCount
        case followingCount
    }
    
    // MARK: - Initialization
    init(id: String, username: String, email: String, createdAt: Date, profilePicUrl: String? = nil, isBusiness: Bool = false, selectedAlgorithms: [String] = [], followersCount: Int = 0, followingCount: Int = 0) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
        self.profilePicUrl = profilePicUrl
        self.isBusiness = isBusiness
        self.selectedAlgorithms = selectedAlgorithms
        self.followersCount = followersCount
        self.followingCount = followingCount
    }
    
    // Create a User from Firebase Auth user
    static func fromFirebaseUser(_ user: FirebaseAuth.User, username: String) -> User {
        User(
            id: user.uid,
            username: username,
            email: user.email ?? "",
            createdAt: Date(),
            profilePicUrl: user.photoURL?.absoluteString,
            isBusiness: false,
            selectedAlgorithms: [],
            followersCount: 0,
            followingCount: 0
        )
    }
    
    // Create a User from Firestore data
    static func fromFirestore(_ data: [String: Any], id: String) -> User? {
        guard let username = data["username"] as? String,
              let email = data["email"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        return User(
            id: id,
            username: username,
            email: email,
            createdAt: createdAt,
            profilePicUrl: data["profilePicUrl"] as? String,
            isBusiness: data["isBusiness"] as? Bool ?? false,
            selectedAlgorithms: data["selectedAlgorithms"] as? [String] ?? [],
            followersCount: data["followersCount"] as? Int ?? 0,
            followingCount: data["followingCount"] as? Int ?? 0
        )
    }
    
    // MARK: - Static Properties
    static let placeholder = User(
        id: "placeholder",
        username: "user",
        email: "",
        createdAt: Date(),
        profilePicUrl: nil,
        isBusiness: false,
        selectedAlgorithms: [],
        followersCount: 0,
        followingCount: 0
    )
    
    // MARK: - Hashable & Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Helper Methods
extension User {
    /// Creates a dictionary representation for Firestore
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "username": username,
            "email": email,
            "createdAt": Timestamp(date: createdAt),
            "isBusiness": isBusiness,
            "selectedAlgorithms": selectedAlgorithms,
            "followersCount": followersCount,
            "followingCount": followingCount
        ]
        
        if let profilePicUrl = profilePicUrl {
            data["profilePicUrl"] = profilePicUrl
        }
        
        return data
    }
}