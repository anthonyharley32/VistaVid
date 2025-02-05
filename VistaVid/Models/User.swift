import Foundation
import FirebaseAuth
import FirebaseFirestore

// User model that matches the Firestore data structure
class User: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    var username: String
    let email: String
    let createdAt: Date
    var profilePicUrl: String?
    var isBusiness: Bool
    var selectedAlgorithms: [String]
    
    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case username
        case email
        case profilePicUrl
        case createdAt
        case isBusiness
        case selectedAlgorithms
    }
    
    // MARK: - Initialization
    init(id: String, username: String, email: String, createdAt: Date, profilePicUrl: String? = nil, isBusiness: Bool = false, selectedAlgorithms: [String] = []) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
        self.profilePicUrl = profilePicUrl
        self.isBusiness = isBusiness
        self.selectedAlgorithms = selectedAlgorithms
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
            selectedAlgorithms: []
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
            selectedAlgorithms: data["selectedAlgorithms"] as? [String] ?? []
        )
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
            "selectedAlgorithms": selectedAlgorithms
        ]
        
        if let profilePicUrl = profilePicUrl {
            data["profilePicUrl"] = profilePicUrl
        }
        
        return data
    }
} 