import Foundation
import FirebaseFirestore

struct Like: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let userId: String
    let videoId: String
    let createdAt: Date
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, userId, videoId, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        videoId = try container.decode(String.self, forKey: .videoId)
        
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
        try container.encode(userId, forKey: .userId)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         userId: String,
         videoId: String,
         createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.videoId = videoId
        self.createdAt = createdAt
    }
}

// MARK: - Firestore Helpers
extension Like {
    static func fromFirestore(_ data: [String: Any], id: String) -> Like? {
        guard let userId = data["userId"] as? String,
              let videoId = data["videoId"] as? String else {
            return nil
        }
        
        return Like(
            id: id,
            userId: userId,
            videoId: videoId,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "videoId": videoId,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
} 