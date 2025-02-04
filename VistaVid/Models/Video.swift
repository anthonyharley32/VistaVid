import Foundation
import FirebaseFirestore

struct Video: Identifiable {
    // MARK: - Properties
    let id: String
    let userId: String
    let videoUrl: String
    let thumbnailUrl: String?
    let description: String
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    let createdAt: Date
    let algorithmTags: [String]
    var businessData: BusinessData?
    
    // MARK: - Business Data Model
    struct BusinessData {
        let trendRating: Double
        let confidenceInterval: String
    }
    
    // MARK: - Initialization
    init(id: String = UUID().uuidString,
         userId: String,
         videoUrl: String,
         thumbnailUrl: String? = nil,
         description: String,
         likesCount: Int = 0,
         commentsCount: Int = 0,
         sharesCount: Int = 0,
         createdAt: Date = Date(),
         algorithmTags: [String] = [],
         businessData: BusinessData? = nil) {
        self.id = id
        self.userId = userId
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.description = description
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.createdAt = createdAt
        self.algorithmTags = algorithmTags
        self.businessData = businessData
    }
    
    // MARK: - Firestore Helpers
    
    /// Create a Video from Firestore data
    static func fromFirestore(_ data: [String: Any], id: String) -> Video? {
        guard let userId = data["userId"] as? String,
              let videoUrl = data["videoUrl"] as? String,
              let description = data["description"] as? String else {
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
            likesCount: data["likesCount"] as? Int ?? 0,
            commentsCount: data["commentsCount"] as? Int ?? 0,
            sharesCount: data["sharesCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            algorithmTags: data["algorithmTags"] as? [String] ?? [],
            businessData: businessData
        )
    }
    
    /// Convert to Firestore data
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "videoUrl": videoUrl,
            "description": description,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "sharesCount": sharesCount,
            "createdAt": Timestamp(date: createdAt),
            "algorithmTags": algorithmTags
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
        
        return data
    }
} 