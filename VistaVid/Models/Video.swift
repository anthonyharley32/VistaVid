import Foundation
import FirebaseFirestore

struct Video: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let userId: String
    var user: User?  // Add user property
    let videoUrl: String
    let thumbnailUrl: String?
    let description: String
    let createdAt: Date
    let algorithmTags: [String]
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    var businessData: BusinessData?
    var status: String // Add status property
    var hlsUrl: String? // Add HLS URL property
    var communityId: String?
    
    var url: URL? {
        URL(string: videoUrl)
    }
    
    // MARK: - Business Data Model
    struct BusinessData: Codable {
        let trendRating: Double
        let confidenceInterval: String
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, userId, videoUrl, thumbnailUrl, description
        case createdAt, algorithmTags, likesCount, commentsCount
        case sharesCount, businessData, status, hlsUrl, communityId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        videoUrl = try container.decode(String.self, forKey: .videoUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        algorithmTags = try container.decode([String].self, forKey: .algorithmTags)
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        sharesCount = try container.decode(Int.self, forKey: .sharesCount)
        businessData = try container.decodeIfPresent(BusinessData.self, forKey: .businessData)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "uploaded"
        hlsUrl = try container.decodeIfPresent(String.self, forKey: .hlsUrl)
        communityId = try container.decodeIfPresent(String.self, forKey: .communityId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(description, forKey: .description)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(algorithmTags, forKey: .algorithmTags)
        try container.encode(likesCount, forKey: .likesCount)
        try container.encode(commentsCount, forKey: .commentsCount)
        try container.encode(sharesCount, forKey: .sharesCount)
        try container.encodeIfPresent(businessData, forKey: .businessData)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(hlsUrl, forKey: .hlsUrl)
        try container.encodeIfPresent(communityId, forKey: .communityId)
    }
    
    // MARK: - Custom Initialization
    init(id: String = UUID().uuidString,
         userId: String,
         videoUrl: String,
         thumbnailUrl: String? = nil,
         description: String,
         createdAt: Date = Date(),
         algorithmTags: [String] = [],
         likesCount: Int = 0,
         commentsCount: Int = 0,
         sharesCount: Int = 0,
         businessData: BusinessData? = nil,
         status: String = "uploading",
         hlsUrl: String? = nil,
         communityId: String? = nil) {
        self.id = id
        self.userId = userId
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.description = description
        self.createdAt = createdAt
        self.algorithmTags = algorithmTags
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.businessData = businessData
        self.status = status
        self.hlsUrl = hlsUrl
        self.communityId = communityId
    }
}

// MARK: - Firestore Helpers
extension Video {
    static func fromFirestore(_ data: [String: Any], id: String) -> Video? {
        guard let userId = data["userId"] as? String,
              let videoUrl = data["videoUrl"] as? String,
              let description = data["description"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let businessData: BusinessData?
        if let businessDict = data["businessData"] as? [String: Any],
           let trendRating = businessDict["trendRating"] as? Double,
           let confidenceInterval = businessDict["confidenceInterval"] as? String {
            businessData = BusinessData(trendRating: trendRating, confidenceInterval: confidenceInterval)
        } else {
            businessData = nil
        }
        
        return Video(
            id: id,
            userId: userId,
            videoUrl: videoUrl,
            thumbnailUrl: data["thumbnailUrl"] as? String,
            description: description,
            createdAt: createdAt,
            algorithmTags: data["algorithmTags"] as? [String] ?? [],
            likesCount: data["likesCount"] as? Int ?? 0,
            commentsCount: data["commentsCount"] as? Int ?? 0,
            sharesCount: data["sharesCount"] as? Int ?? 0,
            businessData: businessData,
            status: data["status"] as? String ?? "uploaded",
            hlsUrl: data["hlsUrl"] as? String,
            communityId: data["communityId"] as? String
        )
    }
    
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "videoUrl": videoUrl,
            "description": description,
            "createdAt": Timestamp(date: createdAt),
            "algorithmTags": algorithmTags,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "sharesCount": sharesCount,
            "status": status
        ]
        
        if let thumbnailUrl = thumbnailUrl {
            data["thumbnailUrl"] = thumbnailUrl
        }
        
        if let businessData = businessData {
            data["businessData"] = [
                "trendRating": businessData.trendRating,
                "confidenceInterval": businessData.confidenceInterval
            ]
        }
        
        if let hlsUrl = hlsUrl {
            data["hlsUrl"] = hlsUrl
        }
        
        if let communityId = communityId {
            data["communityId"] = communityId
        }
        
        return data
    }
} 