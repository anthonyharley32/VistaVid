import Foundation

struct InteractionCounts: Codable, Equatable {
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
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case likes, shares, comments, saves, views
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        likes = try container.decode(Int.self, forKey: .likes)
        shares = try container.decode(Int.self, forKey: .shares)
        comments = try container.decode(Int.self, forKey: .comments)
        saves = try container.decode(Int.self, forKey: .saves)
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(likes, forKey: .likes)
        try container.encode(shares, forKey: .shares)
        try container.encode(comments, forKey: .comments)
        try container.encode(saves, forKey: .saves)
        try container.encode(views, forKey: .views)
    }
} 