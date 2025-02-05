import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let userId: String
    let content: String
    let createdAt: Date
    let parentCommentId: String?
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, userId, content, createdAt, parentCommentId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        content = try container.decode(String.self, forKey: .content)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        parentCommentId = try container.decodeIfPresent(String.self, forKey: .parentCommentId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(content, forKey: .content)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         userId: String,
         content: String,
         createdAt: Date = Date(),
         parentCommentId: String? = nil) {
        self.id = id
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.parentCommentId = parentCommentId
    }
}

// MARK: - Firestore Helpers
extension Comment {
    static func fromFirestore(_ data: [String: Any], id: String) -> Comment? {
        guard let userId = data["userId"] as? String,
              let content = data["content"] as? String else {
            return nil
        }
        
        return Comment(
            id: id,
            userId: userId,
            content: content,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            parentCommentId: data["parentCommentId"] as? String
        )
    }
    
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "content": content,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let parentCommentId = parentCommentId {
            data["parentCommentId"] = parentCommentId
        }
        
        return data
    }
} 