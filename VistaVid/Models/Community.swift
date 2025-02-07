import Foundation
import FirebaseFirestore

struct Community: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let name: String
    let description: String
    let iconType: String // "emoji" or "image"
    let iconEmoji: String?
    let iconImageUrl: String?
    let backgroundColor: String?
    let createdAt: Date
    let creatorId: String
    var membersCount: Int
    var members: [String]
    var moderators: [String]
    
    var displayIcon: String {
        if iconType == "emoji" {
            return iconEmoji ?? "👥"
        }
        return "👥" // Default icon when image is loading
    }
    
    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case iconType
        case iconEmoji
        case iconImageUrl
        case backgroundColor
        case createdAt
        case creatorId
        case membersCount
        case members
        case moderators
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        iconType = try container.decode(String.self, forKey: .iconType)
        iconEmoji = try container.decode(String?.self, forKey: .iconEmoji)
        iconImageUrl = try container.decode(String?.self, forKey: .iconImageUrl)
        backgroundColor = try container.decode(String?.self, forKey: .backgroundColor)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        creatorId = try container.decode(String.self, forKey: .creatorId)
        membersCount = try container.decode(Int.self, forKey: .membersCount)
        members = try container.decode([String].self, forKey: .members)
        moderators = try container.decode([String].self, forKey: .moderators)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(iconType, forKey: .iconType)
        try container.encode(iconEmoji, forKey: .iconEmoji)
        try container.encode(iconImageUrl, forKey: .iconImageUrl)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(membersCount, forKey: .membersCount)
        try container.encode(members, forKey: .members)
        try container.encode(moderators, forKey: .moderators)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         name: String,
         description: String,
         iconType: String = "emoji",
         iconEmoji: String? = "👥",
         iconImageUrl: String? = nil,
         backgroundColor: String? = "#007AFF",
         createdAt: Date = Date(),
         creatorId: String,
         membersCount: Int = 1,
         members: [String] = [],
         moderators: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.iconType = iconType
        self.iconEmoji = iconEmoji
        self.iconImageUrl = iconImageUrl
        self.backgroundColor = backgroundColor
        self.createdAt = createdAt
        self.creatorId = creatorId
        self.membersCount = membersCount
        self.members = members
        self.moderators = moderators
    }
}

// MARK: - Firestore Helpers
extension Community {
    static func fromFirestore(_ data: [String: Any], id: String) -> Community? {
        print("🔄 [Community] Attempting to create from Firestore data - ID: \(id)")
        print("📥 [Community] Raw Firestore data: \(data)")
        
        // Log all required fields
        print("🔍 [Community] Checking required fields:")
        print("  - name: \(data["name"] as? String ?? "missing")")
        print("  - description: \(data["description"] as? String ?? "missing")")
        print("  - iconType: \(data["iconType"] as? String ?? "missing")")
        print("  - creatorId: \(data["creatorId"] as? String ?? "missing")")
        print("  - membersCount: \(data["membersCount"] as? Int ?? -1)")
        
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let iconType = data["iconType"] as? String,
              let creatorId = data["creatorId"] as? String,
              let membersCount = data["membersCount"] as? Int else {
            print("❌ [Community] Failed to parse required fields")
            if data["name"] as? String == nil { print("  ⚠️ name is nil or wrong type") }
            if data["description"] as? String == nil { print("  ⚠️ description is nil or wrong type") }
            if data["iconType"] as? String == nil { print("  ⚠️ iconType is nil or wrong type") }
            if data["creatorId"] as? String == nil { print("  ⚠️ creatorId is nil or wrong type") }
            if data["membersCount"] as? Int == nil { print("  ⚠️ membersCount is nil or wrong type") }
            return nil
        }
        
        // Log optional fields
        print("📎 [Community] Optional fields:")
        print("  - iconEmoji: \(data["iconEmoji"] as? String ?? "not set")")
        print("  - iconImageUrl: \(data["iconImageUrl"] as? String ?? "not set")")
        print("  - backgroundColor: \(data["backgroundColor"] as? String ?? "not set")")
        print("  - members count: \((data["members"] as? [String])?.count ?? 0)")
        print("  - moderators count: \((data["moderators"] as? [String])?.count ?? 0)")
        
        let iconEmoji = data["iconEmoji"] as? String
        let iconImageUrl = data["iconImageUrl"] as? String
        let backgroundColor = data["backgroundColor"] as? String
        let members = data["members"] as? [String] ?? []
        let moderators = data["moderators"] as? [String] ?? []
        
        let community = Community(
            id: id,
            name: name,
            description: description,
            iconType: iconType,
            iconEmoji: iconEmoji,
            iconImageUrl: iconImageUrl,
            backgroundColor: backgroundColor,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            creatorId: creatorId,
            membersCount: membersCount,
            members: members,
            moderators: moderators
        )
        
        print("✅ [Community] Successfully created community object")
        print("  - ID: \(community.id)")
        print("  - Name: \(community.name)")
        print("  - Type: \(community.iconType)")
        
        return community
    }
    
    func toDictionary() -> [String: Any] {
        print("🔍 [Community] Converting to dictionary - ID: \(id)")
        var data: [String: Any] = [
            "id": id,
            "name": name,
            "description": description,
            "iconType": iconType,
            "createdAt": Timestamp(date: createdAt),
            "creatorId": creatorId,
            "membersCount": membersCount,
            "members": members,
            "moderators": moderators
        ]
        
        if let iconEmoji = iconEmoji {
            data["iconEmoji"] = iconEmoji
        }
        
        if let iconImageUrl = iconImageUrl {
            data["iconImageUrl"] = iconImageUrl
        }
        
        if let backgroundColor = backgroundColor {
            data["backgroundColor"] = backgroundColor
        }
        
        print("📦 [Community] Dictionary data: \(data)")
        return data
    }
} 