import Foundation
import FirebaseFirestore

struct Follow: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let followerId: String  // User who is following
    let followingId: String // User being followed
    let createdAt: Date
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, followerId, followingId, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        followerId = try container.decode(String.self, forKey: .followerId)
        followingId = try container.decode(String.self, forKey: .followingId)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(followerId, forKey: .followerId)
        try container.encode(followingId, forKey: .followingId)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         followerId: String,
         followingId: String,
         createdAt: Date = Date()) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = createdAt
    }
    
    // MARK: - Firestore Methods
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> Follow? {
        guard let followerId = data["followerId"] as? String,
              let followingId = data["followingId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        return Follow(
            id: id,
            followerId: followerId,
            followingId: followingId,
            createdAt: createdAt
        )
    }
}
