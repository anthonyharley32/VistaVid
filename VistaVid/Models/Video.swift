import Foundation
import FirebaseFirestore

struct Video: Identifiable, Codable, Equatable {
    // MARK: - Properties
    let id: String
    let creatorId: String
    let title: String
    let description: String
    let videoUrl: String
    let genre: String
    let uploadTimestamp: String
    let preprocessedTutorial: Bool
    var interactionCounts: InteractionCounts
    var user: User?  // Add user property
    let thumbnailUrl: String?
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
        case id, creatorId, title, description, videoUrl, genre, uploadTimestamp, preprocessedTutorial
        case interactionCounts, user, thumbnailUrl, createdAt, algorithmTags, likesCount, commentsCount
        case sharesCount, businessData, status, hlsUrl, communityId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        videoUrl = try container.decode(String.self, forKey: .videoUrl)
        genre = try container.decode(String.self, forKey: .genre)
        uploadTimestamp = try container.decode(String.self, forKey: .uploadTimestamp)
        preprocessedTutorial = try container.decode(Bool.self, forKey: .preprocessedTutorial)
        interactionCounts = try container.decode(InteractionCounts.self, forKey: .interactionCounts)
        user = nil // Initialize optional user
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        
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
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(videoUrl, forKey: .videoUrl)
        try container.encode(genre, forKey: .genre)
        try container.encode(uploadTimestamp, forKey: .uploadTimestamp)
        try container.encode(preprocessedTutorial, forKey: .preprocessedTutorial)
        try container.encode(interactionCounts, forKey: .interactionCounts)
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
         creatorId: String,
         title: String,
         description: String,
         videoUrl: String,
         genre: String,
         uploadTimestamp: String,
         preprocessedTutorial: Bool,
         interactionCounts: InteractionCounts,
         user: User? = nil,
         thumbnailUrl: String? = nil,
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
        self.creatorId = creatorId
        self.title = title
        self.description = description
        self.videoUrl = videoUrl
        self.genre = genre
        self.uploadTimestamp = uploadTimestamp
        self.preprocessedTutorial = preprocessedTutorial
        self.interactionCounts = interactionCounts
        self.user = user
        self.thumbnailUrl = thumbnailUrl
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
    
    // MARK: - Equatable
    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Firestore Helpers
extension Video {
    static func fromFirestore(_ data: [String: Any], id: String) -> Video? {
        // Enable Firestore debug logging
        Firestore.enableLogging(true)
        
        print("🎥 [Video Parser] Starting to parse video with ID: \(id)")
        print("🎥 [Video Parser] Raw data: \(data)")
        
        // Check required fields
        guard let creatorId = data["creatorId"] as? String ?? data["userId"] as? String else {
            print("❌ [Video Parser] Missing or invalid creatorId/userId")
            print("📋 Available fields: \(data.keys.joined(separator: ", "))")
            return nil
        }
        guard let description = data["description"] as? String else {
            print("❌ [Video Parser] Missing or invalid description")
            print("📋 Available fields: \(data.keys.joined(separator: ", "))")
            return nil
        }
        guard let videoUrl = data["videoUrl"] as? String else {
            print("❌ [Video Parser] Missing or invalid videoUrl")
            print("📋 Available fields: \(data.keys.joined(separator: ", "))")
            return nil
        }
        
        // Make title optional with default
        let title = data["title"] as? String ?? "Untitled"
        
        // Make genre optional with default
        let genre = data["genre"] as? String ?? "Other"
        
        // Make uploadTimestamp optional with current timestamp as default
        let uploadTimestamp = data["uploadTimestamp"] as? String ?? ISO8601DateFormatter().string(from: Date())
        
        // Make preprocessedTutorial optional with default false
        let preprocessedTutorial = data["preprocessedTutorial"] as? Bool ?? false
        
        print("✅ [Video Parser] All required fields present")
        
        // Parse interactionCounts with logging
        print("🔄 [Video Parser] Parsing interactionCounts")
        let interactionCounts: InteractionCounts
        if let countsDict = data["interactionCounts"] as? [String: Int] {
            print("📊 [Video Parser] Found interactionCounts dictionary: \(countsDict)")
            interactionCounts = InteractionCounts(
                likes: countsDict["likes"] ?? 0,
                shares: countsDict["shares"] ?? 0,
                comments: countsDict["comments"] ?? 0,
                saves: countsDict["saves"] ?? 0,
                views: countsDict["views"] ?? 0
            )
        } else {
            print("⚠️ [Video Parser] No interactionCounts found, using defaults")
            interactionCounts = InteractionCounts(likes: 0, shares: 0, comments: 0, saves: 0, views: 0)
        }
        
        // Parse business data with logging
        print("🔄 [Video Parser] Parsing businessData")
        let businessData: BusinessData?
        if let businessDict = data["businessData"] as? [String: Any],
           let trendRating = businessDict["trendRating"] as? Double,
           let confidenceInterval = businessDict["confidenceInterval"] as? String {
            print("📈 [Video Parser] Found businessData")
            businessData = BusinessData(trendRating: trendRating, confidenceInterval: confidenceInterval)
        } else {
            print("ℹ️ [Video Parser] No businessData found")
            businessData = nil
        }
        
        // Parse timestamps with logging
        print("🔄 [Video Parser] Parsing createdAt timestamp")
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            print("📅 [Video Parser] Found Timestamp: \(timestamp)")
            createdAt = timestamp.dateValue()
        } else {
            print("⚠️ [Video Parser] No createdAt timestamp found, using current date")
            createdAt = Date()
        }
        
        // Create and return video object
        let video = Video(
            id: id,
            creatorId: creatorId,
            title: title,
            description: description,
            videoUrl: videoUrl,
            genre: genre,
            uploadTimestamp: uploadTimestamp,
            preprocessedTutorial: preprocessedTutorial,
            interactionCounts: interactionCounts,
            user: nil,
            thumbnailUrl: data["thumbnailUrl"] as? String,
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
        
        print("✅ [Video Parser] Successfully created Video object")
        return video
    }
    
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "creatorId": creatorId,
            "title": title,
            "description": description,
            "videoUrl": videoUrl,
            "genre": genre,
            "uploadTimestamp": uploadTimestamp,
            "preprocessedTutorial": preprocessedTutorial,
            "interactionCounts": [
                "likes": interactionCounts.likes,
                "shares": interactionCounts.shares,
                "comments": interactionCounts.comments,
                "saves": interactionCounts.saves,
                "views": interactionCounts.views
            ],
            "createdAt": Timestamp(date: createdAt),
            "algorithmTags": algorithmTags,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "sharesCount": sharesCount,
            "status": status,
            "qualities": ["1080p", "720p", "480p", "360p"]  // Add default qualities
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

// MARK: - InteractionCounts
extension Video {
    struct InteractionCounts: Codable {
        var likes: Int
        var shares: Int
        var comments: Int
        var saves: Int
        var views: Int
        
        init(likes: Int = 0, shares: Int = 0, comments: Int = 0, saves: Int = 0, views: Int = 0) {
            self.likes = likes
            self.shares = shares
            self.comments = comments
            self.saves = saves
            self.views = views
        }
    }
}

// MARK: - For preview/testing only
extension Video {
    static func random() -> Video {
        Video(
            id: UUID().uuidString,
            creatorId: UUID().uuidString,
            title: "Sample Video",
            description: "This is a sample video description",
            videoUrl: "",
            genre: "Pop",
            uploadTimestamp: ISO8601DateFormatter().string(from: Date()),
            preprocessedTutorial: false,
            interactionCounts: InteractionCounts(
                likes: 0,
                shares: 0,
                comments: 0,
                saves: 0,
                views: 0
            )
        )
    }
} 