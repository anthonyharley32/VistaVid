import Foundation
import FirebaseAuth

// User model that matches the Firestore data structure
struct User: Identifiable, Codable {
    // MARK: - Properties
    let id: String            // FirebaseAuth.uid
    var username: String
    var email: String
    var profilePicUrl: String?
    var createdAt: Date
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
    init(id: String, username: String, email: String, profilePicUrl: String? = nil, createdAt: Date = Date(), isBusiness: Bool = false, selectedAlgorithms: [String] = []) {
        self.id = id
        self.username = username
        self.email = email
        self.profilePicUrl = profilePicUrl
        self.createdAt = createdAt
        self.isBusiness = isBusiness
        self.selectedAlgorithms = selectedAlgorithms
    }
}

// MARK: - Helper Methods
extension User {
    /// Creates a dictionary representation for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "userId": id,
            "username": username,
            "email": email,
            "profilePicUrl": profilePicUrl as Any,
            "createdAt": createdAt,
            "isBusiness": isBusiness,
            "selectedAlgorithms": selectedAlgorithms
        ]
    }
    
    /// Creates a User from Firebase User
    static func fromFirebaseUser(_ firebaseUser: FirebaseAuth.User, username: String) -> User {
        return User(
            id: firebaseUser.uid,
            username: username,
            email: firebaseUser.email ?? "",
            profilePicUrl: firebaseUser.photoURL?.absoluteString
        )
    }
} 