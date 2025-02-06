import Foundation
import FirebaseFirestore

struct ChatThread: Identifiable, Codable {
    let id: String
    let participantIds: [String]
    let lastMessage: Message?
    let lastActivityAt: Date
    var unreadCount: Int
    var participants: [User]?
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, participantIds, lastMessage, lastActivityAt, unreadCount, participants
    }
    
    init(id: String = UUID().uuidString,
         participantIds: [String],
         lastMessage: Message? = nil,
         lastActivityAt: Date = Date(),
         unreadCount: Int = 0,
         participants: [User]? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastActivityAt = lastActivityAt
        self.unreadCount = unreadCount
        self.participants = participants
    }
    
    // MARK: - Firestore Methods
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "participantIds": participantIds,
            "lastActivityAt": Timestamp(date: lastActivityAt),
            "unreadCount": unreadCount
        ]
        
        if let lastMessage = lastMessage {
            data["lastMessage"] = lastMessage.toDictionary()
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> ChatThread? {
        guard let participantIds = data["participantIds"] as? [String],
              let lastActivityAt = (data["lastActivityAt"] as? Timestamp)?.dateValue(),
              let unreadCount = data["unreadCount"] as? Int else {
            return nil
        }
        
        var lastMessage: Message?
        if let messageData = data["lastMessage"] as? [String: Any] {
            lastMessage = Message.fromFirestore(messageData, id: messageData["id"] as? String ?? UUID().uuidString)
        }
        
        return ChatThread(
            id: id,
            participantIds: participantIds,
            lastMessage: lastMessage,
            lastActivityAt: lastActivityAt,
            unreadCount: unreadCount
        )
    }
}
