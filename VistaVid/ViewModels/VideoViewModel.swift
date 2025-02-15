import Foundation
import FirebaseFirestore
import FirebaseStorage
import AVFoundation
import FirebaseAuth

@MainActor
final class VideoViewModel: ObservableObject {
    // MARK: - Properties
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let db: Firestore
    private let storage = Storage.storage()
    private var lastDocument: DocumentSnapshot?
    private let batchSize = 10
    
    // MARK: - Debug Properties
    private let debug = true
    
    private let auth = Auth.auth()
    
    // MARK: - Initializer
    init() {
        self.db = FirestoreService.shared.db
    }
    
    // MARK: - Video Feed Methods
    
    /// Fetches the initial batch of videos
    func fetchInitialVideos() async {
        debugLog("🎬 Fetching initial videos")
        debugLog("🔥 Using Firestore instance: \(db)")
        isLoading = true
        defer { isLoading = false }
        
        // Enable Firestore debug logging
        Firestore.enableLogging(true)
        
        // Add retry logic
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            do {
                let query = db.collection("videos")
                    .whereField("status", isEqualTo: "processed")
                    .order(by: "createdAt", descending: true)
                    .limit(to: batchSize)
                
                debugLog("🔍 Executing query: \(query)")
                debugLog("🔄 Attempt \(currentRetry + 1) of \(maxRetries)")
                
                let snapshot = try await query.getDocuments()
                debugLog("📄 Got \(snapshot.documents.count) videos")
                
                if snapshot.documents.isEmpty {
                    debugLog("⚠️ No videos found in database")
                    return
                }
                
                var processedVideos: [Video] = []
                
                // Process each video document
                for document in snapshot.documents {
                    debugLog("🎥 Processing video: \(document.documentID)")
                    let data = document.data()
                    debugLog("📋 Video data: \(data)")
                    
                    guard var video = Video.fromFirestore(data, id: document.documentID) else {
                        debugLog("❌ Failed to parse video: \(document.documentID)")
                        continue
                    }
                    
                    // Fetch user data for the video
                    if let userData = await fetchUserForVideo(video) {
                        video.user = userData
                        debugLog("👤 Added user data to video: \(document.documentID)")
                    }
                    
                    processedVideos.append(video)
                    debugLog("✅ Successfully processed video: \(document.documentID)")
                }
                
                debugLog("📊 Successfully parsed \(processedVideos.count) out of \(snapshot.documents.count) videos")
                
                // Update videos array on main thread
                await MainActor.run {
                    self.videos = processedVideos
                    self.lastDocument = snapshot.documents.last
                }
                
                debugLog("✅ Successfully fetched initial videos: \(processedVideos.count) videos loaded")
                return
                
            } catch {
                debugLog("❌ Error fetching videos (attempt \(currentRetry + 1)): \(error.localizedDescription)")
                debugLog("🔍 Detailed error: \(error)")
                currentRetry += 1
                
                if currentRetry < maxRetries {
                    debugLog("⏳ Waiting before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * currentRetry))
                } else {
                    await MainActor.run {
                        self.error = error
                    }
                    debugLog("❌ All retry attempts failed")
                }
            }
        }
    }
    
    /// Fetches the next batch of videos for infinite scrolling
    func fetchNextBatch() async {
        guard let lastDocument = lastDocument else {
            debugLog("ℹ️ No more videos to fetch")
            return
        }
        
        debugLog("🎬 Fetching next batch of videos")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = db.collection("videos")
                .whereField("status", isEqualTo: "processed")
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDocument)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) more videos")
            
            var processedVideos: [Video] = []
            
            // Process each video document
            for document in snapshot.documents {
                debugLog("🎥 Processing video: \(document.documentID)")
                guard var video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video: \(document.documentID)")
                    continue
                }
                
                // Fetch user data for the video
                if let userData = await fetchUserForVideo(video) {
                    video.user = userData
                    debugLog("👤 Added user data to video: \(document.documentID)")
                }
                
                processedVideos.append(video)
                debugLog("✅ Successfully processed video: \(document.documentID)")
            }
            
            debugLog("📊 Successfully parsed \(processedVideos.count) out of \(snapshot.documents.count) videos")
            
            // Update videos array on main thread
            await MainActor.run {
                self.videos.append(contentsOf: processedVideos)
                self.lastDocument = snapshot.documents.last
            }
            
            debugLog("✅ Successfully fetched next batch")
            
        } catch {
            debugLog("❌ Error fetching next batch: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    // MARK: - Video Upload Methods
    
    /// Uploads a new video
    func uploadVideo(videoURL: URL, description: String, algorithmTags: [String], communityId: String? = nil) async throws -> String {
        debugLog("📤 Starting video upload process")
        
        // Check authentication
        guard let currentUser = auth.currentUser else {
            debugLog("❌ No authenticated user found")
            throw NSError(domain: "VideoUpload", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        debugLog("👤 Current user ID: \(currentUser.uid)")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Generate a unique ID for the video
            let videoId = UUID().uuidString
            debugLog("🆔 Generated video ID: \(videoId)")
            
            // Create storage reference
            let videoRef = storage.reference().child("videos/\(videoId).mp4")
            debugLog("📁 Storage path: \(videoRef.fullPath)")
            
            // Get video metadata
            let videoAsset = AVURLAsset(url: videoURL)
            let duration = try await videoAsset.load(.duration)
            let durationInSeconds = CMTimeGetSeconds(duration)
            debugLog("⏱️ Video duration: \(durationInSeconds) seconds")
            debugLog("📏 Video file size: \(try Data(contentsOf: videoURL).count) bytes")
            
            // Create initial Firestore document
            debugLog("📝 Creating initial Firestore document")
            let initialVideo = Video(
                id: videoId,
                creatorId: currentUser.uid,
                title: "Untitled",
                description: description,
                videoUrl: "",
                genre: "Other",
                uploadTimestamp: ISO8601DateFormatter().string(from: Date()),
                preprocessedTutorial: false,
                interactionCounts: Video.InteractionCounts(
                    likes: 0,
                    shares: 0,
                    comments: 0,
                    saves: 0,
                    views: 0
                ),
                user: nil,
                thumbnailUrl: nil,
                createdAt: Date(),
                algorithmTags: algorithmTags,
                likesCount: 0,
                commentsCount: 0,
                sharesCount: 0,
                businessData: nil,
                status: "uploading",
                hlsUrl: nil,
                communityId: communityId
            )
            var initialVideoDict = initialVideo.toDictionary()
            initialVideoDict["status"] = "uploading" // Add status field
            try await db.collection("videos").document(videoId).setData(initialVideoDict)
            debugLog("✅ Created initial video document")
            
            // Upload video data
            debugLog("📤 Starting video file upload")
            let videoData = try Data(contentsOf: videoURL)
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            metadata.customMetadata = [
                "creatorId": currentUser.uid,
                "videoId": videoId
            ]
            
            debugLog("📤 Uploading to Firebase Storage...")
            _ = try await videoRef.putDataAsync(videoData, metadata: metadata)
            debugLog("✅ Video file uploaded successfully")
            
            let videoDownloadURL = try await videoRef.downloadURL()
            debugLog("🔗 Video download URL: \(videoDownloadURL.absoluteString)")
            
            // Update status to uploaded
            debugLog("📝 Updating video status")
            try await db.collection("videos").document(videoId).updateData(VideoStatus.uploaded.asDictionary)
            debugLog("✅ Updated video status to uploaded")
            
            // Generate and upload thumbnail
            debugLog("🖼️ Generating thumbnail")
            if let thumbnail = try await generateThumbnail(for: videoURL),
               let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                let thumbnailRef = storage.reference().child("thumbnails/\(videoId).jpg")
                let metadata = MediaMetadata(creatorId: currentUser.uid, videoId: videoId)
                debugLog("📤 Uploading thumbnail")
                _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: metadata.asMetadata)
                let thumbnailUrl = try await thumbnailRef.downloadURL().absoluteString
                debugLog("✅ Thumbnail uploaded successfully")
                
                // Update video document with URLs
                debugLog("📝 Updating Firestore document with URLs")
                let updateData: [String: String] = [
                    "videoUrl": videoDownloadURL.absoluteString,
                    "thumbnailUrl": thumbnailUrl
                ]
                try await db.collection("videos").document(videoId).updateData(updateData)
                debugLog("✅ Video document updated with URLs")
                debugLog("🎉 Upload process completed successfully")
            }
            
            // After successful upload, refresh the feed
            debugLog("🔄 Refreshing video feed after upload")
            await fetchInitialVideos()
            
            return videoId
            
        } catch {
            debugLog("❌ Error uploading video: \(error)")
            debugLog("❌ Detailed error: \(String(describing: error))")
            throw error
        }
    }
    
    // MARK: - Video Loading
    
    func loadVideos() async {
        print("📱 [VideoViewModel]: Loading videos")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            var loadedVideos: [Video] = []
            
            for document in snapshot.documents {
                guard var video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video document: \(document.documentID)")
                    continue
                }
                
                // Fetch user data for each video
                video.user = await fetchUserForVideo(video)
                loadedVideos.append(video)
            }
            
            videos = loadedVideos
            lastDocument = snapshot.documents.last
            debugLog("✅ Successfully loaded videos with user data")
            
        } catch {
            debugLog("❌ Error loading videos: \(error)")
            self.error = error
        }
    }
    
    /// Fetches user data for a video
    func fetchUserForVideo(_ video: Video) async -> User? {
        debugLog("👤 Fetching user data for video: \(video.id)")
        
        do {
            let userDoc = try await db.collection("users").document(video.creatorId).getDocument()
            guard let userData = userDoc.data() else {
                debugLog("❌ No user data found for ID: \(video.creatorId)")
                return nil
            }
            
            // Add the userId as the document ID
            var userDataWithId = userData
            userDataWithId["userId"] = userDoc.documentID
            
            let user = try Firestore.Decoder().decode(User.self, from: userDataWithId)
            debugLog("✅ Successfully fetched user data for video")
            return user
        } catch {
            debugLog("❌ Error fetching user data: \(error)")
            return nil
        }
    }
    
    // MARK: - Algorithm Filtering Methods
    
    /// Fetches videos filtered by algorithm tags
    func fetchVideosWithAlgorithms(_ algorithms: [String]) async {
        debugLog("🎯 Fetching videos with algorithms: \(algorithms)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = db.collection("videos")
                .whereField("algorithmTags", arrayContainsAny: algorithms)
                .order(by: "createdAt", descending: true)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) filtered videos")
            
            videos = snapshot.documents.compactMap { document in
                guard let video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video document: \(document.documentID)")
                    return nil
                }
                return video
            }
            
            lastDocument = snapshot.documents.last
            debugLog("✅ Successfully fetched filtered videos")
            
        } catch {
            debugLog("❌ Error fetching filtered videos: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Fetches the next batch of algorithm-filtered videos
    func fetchNextBatchWithAlgorithms(_ algorithms: [String]) async {
        guard let lastDocument = lastDocument else {
            debugLog("ℹ️ No more filtered videos to fetch")
            return
        }
        
        debugLog("🎯 Fetching next batch of filtered videos")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = db.collection("videos")
                .whereField("algorithmTags", arrayContainsAny: algorithms)
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDocument)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) more filtered videos")
            
            let newVideos = snapshot.documents.compactMap { document -> Video? in
                Video.fromFirestore(document.data(), id: document.documentID)
            }
            
            videos.append(contentsOf: newVideos)
            self.lastDocument = snapshot.documents.last
            debugLog("✅ Successfully fetched next filtered batch")
            
        } catch {
            debugLog("❌ Error fetching next filtered batch: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    // MARK: - Like Methods
    @Sendable
    private func updateVideoData(_ data: [String: Any], for ref: DocumentReference) async throws {
        try await ref.updateData(data)
    }
    
    @Sendable
    private func setDocumentData(_ data: [String: Any], for ref: DocumentReference) async throws {
        try await ref.setData(data)
    }
    
    func toggleLike(for video: Video) async throws {
        guard let currentUser = auth.currentUser else {
            debugLog("❌ No authenticated user found")
            throw NSError(domain: "VideoLike", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let videoRef = db.collection("videos").document(video.id)
        let likeRef = videoRef.collection("likes").document(currentUser.uid)
        
        do {
            let likeDoc = try await likeRef.getDocument()
            
            if likeDoc.exists {
                // Unlike
                try await likeRef.delete()
                let updateData = ["likesCount": FieldValue.increment(Int64(-1))] as [String: Any]
                try await updateVideoData(updateData, for: videoRef)
                debugLog("✅ Successfully unliked video")
            } else {
                // Like
                let like = Like(
                    id: UUID().uuidString,
                    userId: currentUser.uid,
                    videoId: video.id,
                    createdAt: Date()
                )
                try await setDocumentData(like.toDictionary(), for: likeRef)
                try await updateVideoData(["likesCount": FieldValue.increment(Int64(1))], for: videoRef)
                debugLog("✅ Successfully liked video")
            }
            
            // Update local video object
            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                var updatedVideo = videos[index]
                updatedVideo.likesCount = likeDoc.exists ? video.likesCount - 1 : video.likesCount + 1
                videos[index] = updatedVideo
            }
            
        } catch {
            debugLog("❌ Error toggling like: \(error)")
            throw error
        }
    }
    
    func checkLikeStatus(for video: Video) async throws -> Bool {
        guard let currentUser = auth.currentUser else {
            debugLog("❌ No authenticated user found")
            throw NSError(domain: "VideoLike", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        do {
            let likeDoc = try await db.collection("videos")
                .document(video.id)
                .collection("likes")
                .document(currentUser.uid)
                .getDocument()
            
            return likeDoc.exists
        } catch {
            debugLog("❌ Error checking like status: \(error)")
            throw error
        }
    }
    
    func fetchLikes(for video: Video) async throws -> [Like] {
        debugLog("📥 Fetching likes for video: \(video.id)")
        do {
            let snapshot = try await db.collection("videos")
                .document(video.id)
                .collection("likes")
                .getDocuments()
            
            let likes = snapshot.documents.compactMap { doc -> Like? in
                Like.fromFirestore(doc.data(), id: doc.documentID)
            }
            
            debugLog("✅ Successfully fetched \(likes.count) likes")
            return likes
        } catch {
            debugLog("❌ Error fetching likes: \(error)")
            throw error
        }
    }
    
    // MARK: - Comment Methods
    func addComment(to video: Video, text: String) async throws {
        guard let currentUser = auth.currentUser else {
            debugLog("❌ No authenticated user found")
            throw NSError(domain: "VideoComment", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let videoRef = db.collection("videos").document(video.id)
        let commentsRef = videoRef.collection("comments")
        
        let commentData = [
            "userId": currentUser.uid,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ] as [String: Any]
        
        do {
            // Add comment
            try await commentsRef.addDocument(data: commentData)
            
            // Increment comment count
            try await updateVideoData([
                "commentsCount": FieldValue.increment(Int64(1))
            ], for: videoRef)
            
            // Update local video object
            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                var updatedVideo = videos[index]
                updatedVideo.commentsCount += 1
                videos[index] = updatedVideo
            }
            
            debugLog("✅ Successfully added comment")
        } catch {
            debugLog("❌ Error adding comment: \(error)")
            throw error
        }
    }
    
    func fetchComments(for video: Video) async throws -> [(id: String, userId: String, text: String, createdAt: Date)] {
        do {
            let snapshot = try await db.collection("videos")
                .document(video.id)
                .collection("comments")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> (String, String, String, Date)? in
                guard let userId = doc.data()["userId"] as? String,
                      let text = doc.data()["text"] as? String,
                      let timestamp = doc.data()["createdAt"] as? Timestamp else {
                    return nil
                }
                return (doc.documentID, userId, text, timestamp.dateValue())
            }
        } catch {
            debugLog("❌ Error loading comments: \(error)")
            throw error
        }
    }
    
    // MARK: - Share Methods
    func shareVideo(_ video: Video) {
        debugLog("📤 Sharing video: \(video.id)")
        // Don't increment share count in Firestore
        // This should be handled by the UI layer for sharing functionality
    }
    
    // MARK: - User Videos
    
    func fetchUserVideos(userId: String) async throws -> [Video] {
        debugLog("🎬 Fetching videos for user: \(userId)")
        
        do {
            // First try to get videos without ordering
            let query = db.collection("videos")
                .whereField("creatorId", isEqualTo: userId)
                .whereField("status", isEqualTo: "processed")  // Only fetch processed videos
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) videos for user")
            
            if snapshot.documents.isEmpty {
                debugLog("⚠️ No videos found for user")
                return []
            }
            
            var userVideos = [Video]()
            
            // Process videos one by one with proper error handling
            for document in snapshot.documents {
                debugLog("📝 Processing video document: \(document.documentID)")
                guard var video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video document: \(document.documentID)")
                    continue
                }
                
                // Safely fetch user data
                if let userData = await fetchUserForVideo(video) {
                    video.user = userData
                    debugLog("👤 Added user data to video: \(document.documentID)")
                }
                    
                userVideos.append(video)
                debugLog("✅ Successfully processed video: \(document.documentID)")
            }
            
            // Sort in memory instead of using Firestore ordering
            userVideos.sort { $0.createdAt > $1.createdAt }
            debugLog("📊 Sorted \(userVideos.count) videos by creation date")
            
            return userVideos
            
        } catch let error as NSError {
            debugLog("❌ Error fetching user videos: \(error.localizedDescription)")
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 9 {
                debugLog("⚠️ Missing index error - attempting to fetch without ordering")
                // If index error, try without ordering
                let query = db.collection("videos")
                    .whereField("creatorId", isEqualTo: userId)
                    .whereField("status", isEqualTo: "processed")  // Only fetch processed videos
                
                let snapshot = try await query.getDocuments()
                var videos = [Video]()
                
                for document in snapshot.documents {
                    if var video = Video.fromFirestore(document.data(), id: document.documentID) {
                        if let userData = await fetchUserForVideo(video) {
                            video.user = userData
                        }
                        videos.append(video)
                    }
                }
                
                videos.sort { $0.createdAt > $1.createdAt }
                return videos
            }
            throw error
        }
    }
    
    func fetchLikedVideos(userId: String) async throws -> [Video] {
        debugLog("❤️ Fetching liked videos for user: \(userId)")
        
        do {
            // Get all likes for the user
            let likesSnapshot = try await db.collectionGroup("likes")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)  // Add ordering by createdAt
                .getDocuments()
            
            debugLog("📄 Found \(likesSnapshot.documents.count) likes")
            
            if likesSnapshot.documents.isEmpty {
                debugLog("⚠️ No liked videos found")
                return []
            }
            
            // Get video IDs from likes
            let videoIds = likesSnapshot.documents.compactMap { doc -> String? in
                // Get the video ID from the reference path
                let pathComponents = doc.reference.path.components(separatedBy: "/")
                // The path format is "videos/{videoId}/likes/{likeId}"
                guard pathComponents.count >= 2 else { return nil }
                return pathComponents[1] // This is the videoId
            }
            
            debugLog("🎯 Found video IDs: \(videoIds)")
            
            // Fetch videos in batches of 10
            var likedVideos: [Video] = []
            for chunk in videoIds.chunked(into: 10) {
                let videosSnapshot = try await db.collection("videos")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                // Process each video document and fetch user data
                for doc in videosSnapshot.documents {
                    debugLog("📝 Processing video document: \(doc.documentID)")
                    guard var video = Video.fromFirestore(doc.data(), id: doc.documentID) else {
                        debugLog("❌ Failed to parse video document: \(doc.documentID)")
                        continue
                    }
                    // Fetch user data for the video
                    video.user = await fetchUserForVideo(video)
                    debugLog("✅ Successfully processed video: \(doc.documentID)")
                    likedVideos.append(video)
                }
            }
            
            // Sort by the original like order (most recent first)
            let orderedVideoIds = videoIds
            likedVideos.sort { first, second in
                let firstIndex = orderedVideoIds.firstIndex(of: first.id) ?? 0
                let secondIndex = orderedVideoIds.firstIndex(of: second.id) ?? 0
                return firstIndex < secondIndex
            }
            
            debugLog("✅ Successfully fetched \(likedVideos.count) liked videos")
            return likedVideos
            
        } catch {
            debugLog("❌ Error fetching liked videos: \(error)")
            throw error
        }
    }
    
    // MARK: - Video Status
    private enum VideoStatus: String, Sendable {
        case uploaded = "uploaded"
        
        var asDictionary: [String: String] { ["status": rawValue] }
    }
    
    // MARK: - Metadata Types
    private struct MediaMetadata: Sendable {
        let creatorId: String
        let videoId: String
        
        var asMetadata: StorageMetadata {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            metadata.customMetadata = ["creatorId": creatorId, "videoId": videoId]
            return metadata
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates a thumbnail from a video URL
    func generateThumbnail(for videoURL: URL) async throws -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await generator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            debugLog("❌ Failed to generate thumbnail: \(error)")
            throw error
        }
    }
    
    /// Debug logging
    private func debugLog(_ message: String) {
        if debug {
            print("🎥 [Video]: \(message)")
        }
    }
    
    // MARK: - Community Videos
    
    /// Fetches videos for a specific community
    func fetchCommunityVideos(communityId: String) async throws -> [Video] {
        debugLog("🎬 Fetching videos for community: \(communityId)")
        
        do {
            let query = db.collection("videos")
                .whereField("communityId", isEqualTo: communityId)
                .order(by: "createdAt", descending: true)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) community videos")
            
            let videos = snapshot.documents.compactMap { document -> Video? in
                guard let video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video document: \(document.documentID)")
                    return nil
                }
                return video
            }
            
            debugLog("✅ Successfully fetched community videos")
            return videos
        } catch {
            debugLog("❌ Error fetching community videos: \(error)")
            throw error
        }
    }
    
    // MARK: - View Count Methods
    func incrementViewCount(for video: Video) async throws {
        debugLog("👁️ Incrementing view count for video: \(video.id)")
        
        let videoRef = db.collection("videos").document(video.id)
        
        do {
            // Increment view count in Firestore
            try await updateVideoData([
                "interactionCounts.views": FieldValue.increment(Int64(1))
            ], for: videoRef)
            
            // Update local video object
            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                var updatedVideo = videos[index]
                updatedVideo.interactionCounts.views += 1
                videos[index] = updatedVideo
            }
            
            debugLog("✅ Successfully incremented view count")
        } catch {
            debugLog("❌ Error incrementing view count: \(error)")
            throw error
        }
    }
    
    // MARK: - Video Status Methods
    
    /// Fetches the current status of a video
    func getVideoStatus(_ videoId: String) async throws -> (status: String, error: String?) {
        debugLog("🔍 Checking status for video: \(videoId)")
        
        do {
            let doc = try await db.collection("videos").document(videoId).getDocument()
            guard let data = doc.data() else {
                throw NSError(domain: "VideoStatus", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video not found"])
            }
            
            let status = data["status"] as? String ?? "unknown"
            let error = data["error"] as? String
            
            debugLog("📊 Video status: \(status)")
            return (status: status, error: error)
        } catch {
            debugLog("❌ Error fetching video status: \(error)")
            throw error
        }
    }
}

// MARK: - Array Extension
fileprivate extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}