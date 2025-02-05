import Foundation
import FirebaseFirestore

struct Community: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let name: String
    let description: String
    let createdAt: Date
    let members: [String]
    let moderators: [String]
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, description, createdAt, members, moderators
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        members = try container.decode([String].self, forKey: .members)
        moderators = try container.decode([String].self, forKey: .moderators)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(members, forKey: .members)
        try container.encode(moderators, forKey: .moderators)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         name: String,
         description: String,
         createdAt: Date = Date(),
         members: [String] = [],
         moderators: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.members = members
        self.moderators = moderators
    }
}

// MARK: - Firestore Helpers
extension Community {
    static func fromFirestore(_ data: [String: Any], id: String) -> Community? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let members = data["members"] as? [String],
              let moderators = data["moderators"] as? [String] else {
            return nil
        }
        
        return Community(
            id: id,
            name: name,
            description: description,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            members: members,
            moderators: moderators
        )
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "createdAt": Timestamp(date: createdAt),
            "members": members,
            "moderators": moderators
        ]
    }
} 