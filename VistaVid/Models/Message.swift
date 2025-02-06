import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let senderId: String
    let recipientId: String
    let content: String
    let createdAt: Date
    var isRead: Bool
    var attachmentUrl: String?
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, senderId, recipientId, content, createdAt, isRead, attachmentUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        senderId = try container.decode(String.self, forKey: .senderId)
        recipientId = try container.decode(String.self, forKey: .recipientId)
        content = try container.decode(String.self, forKey: .content)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        attachmentUrl = try container.decodeIfPresent(String.self, forKey: .attachmentUrl)
        
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
        try container.encode(senderId, forKey: .senderId)
        try container.encode(recipientId, forKey: .recipientId)
        try container.encode(content, forKey: .content)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(attachmentUrl, forKey: .attachmentUrl)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         senderId: String,
         recipientId: String,
         content: String,
         createdAt: Date = Date(),
         isRead: Bool = false,
         attachmentUrl: String? = nil) {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.content = content
        self.createdAt = createdAt
        self.isRead = isRead
        self.attachmentUrl = attachmentUrl
    }
    
    // MARK: - Firestore Methods
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "senderId": senderId,
            "recipientId": recipientId,
            "content": content,
            "createdAt": Timestamp(date: createdAt),
            "isRead": isRead
        ]
        
        if let attachmentUrl = attachmentUrl {
            data["attachmentUrl"] = attachmentUrl
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> Message? {
        guard let senderId = data["senderId"] as? String,
              let recipientId = data["recipientId"] as? String,
              let content = data["content"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let isRead = data["isRead"] as? Bool else {
            return nil
        }
        
        return Message(
            id: id,
            senderId: senderId,
            recipientId: recipientId,
            content: content,
            createdAt: createdAt,
            isRead: isRead,
            attachmentUrl: data["attachmentUrl"] as? String
        )
    }
}
