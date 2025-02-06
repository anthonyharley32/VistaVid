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
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let batchSize = 10
    
    // MARK: - Debug Properties
    private let debug = true
    
    private let storage = Storage.storage().reference()
    private let auth = Auth.auth()
    
    // MARK: - Video Feed Methods
    
    /// Fetches the initial batch of videos
    func fetchInitialVideos() async {
        debugLog("🎬 Fetching initial videos")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) videos")
            
            videos = snapshot.documents.compactMap { document in
                guard let video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video document: \(document.documentID)")
                    return nil
                }
                return video
            }
            
            lastDocument = snapshot.documents.last
            debugLog("✅ Successfully fetched initial videos")
            
        } catch {
            debugLog("❌ Error fetching videos: \(error.localizedDescription)")
            self.error = error
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
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDocument)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) more videos")
            
            let mappedVideos = snapshot.documents.map { document in
                Video.fromFirestore(document.data(), id: document.documentID)
            }
            let newVideos = mappedVideos.compactMap { $0 }
            
            videos.append(contentsOf: newVideos)
            self.lastDocument = snapshot.documents.last
            debugLog("✅ Successfully fetched next batch")
            
        } catch {
            debugLog("❌ Error fetching next batch: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    // MARK: - Video Upload Methods
    
    /// Uploads a new video
    func uploadVideo(videoURL: URL, description: String, algorithmTags: [String]) async throws {
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
            let videoRef = storage.child("videos/\(videoId).mp4")
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
                userId: currentUser.uid,
                videoUrl: "", // Will be updated after upload
                thumbnailUrl: nil,
                description: description,
                createdAt: Date(),
                algorithmTags: algorithmTags
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
                "userId": currentUser.uid,
                "videoId": videoId
            ]
            
            debugLog("📤 Uploading to Firebase Storage...")
            _ = try await videoRef.putDataAsync(videoData, metadata: metadata)
            debugLog("✅ Video file uploaded successfully")
            
            let videoDownloadURL = try await videoRef.downloadURL()
            debugLog("🔗 Video download URL: \(videoDownloadURL.absoluteString)")
            
            // Update status to uploaded
            try await db.collection("videos").document(videoId).updateData([
                "status": "uploaded"
            ])
            debugLog("✅ Updated video status to uploaded")
            
            // Generate and upload thumbnail
            debugLog("🖼️ Generating thumbnail")
            if let thumbnail = try await generateThumbnail(for: videoURL),
               let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                let thumbnailRef = storage.child("thumbnails/\(videoId).jpg")
                let thumbnailMetadata = StorageMetadata()
                thumbnailMetadata.contentType = "image/jpeg"
                thumbnailMetadata.customMetadata = [
                    "userId": currentUser.uid,
                    "videoId": videoId
                ]
                
                debugLog("📤 Uploading thumbnail")
                try await thumbnailRef.putDataAsync(thumbnailData, metadata: thumbnailMetadata)
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
    
    private func fetchUserForVideo(_ video: Video) async -> User? {
        do {
            let userDoc = try await db.collection("users").document(video.userId).getDocument()
            guard let userData = userDoc.data() else { return nil }
            
            return User(
                id: video.userId,
                username: userData["username"] as? String ?? "unknown",
                email: userData["email"] as? String ?? "",
                createdAt: (userData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                profilePicUrl: userData["profilePicUrl"] as? String,
                isBusiness: userData["isBusiness"] as? Bool ?? false,
                selectedAlgorithms: userData["selectedAlgorithms"] as? [String] ?? []
            )
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
                let like = Like(userId: currentUser.uid, videoId: video.id)
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
                .whereField("userId", isEqualTo: userId)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) videos for user")
            
            if snapshot.documents.isEmpty {
                debugLog("⚠️ No videos found for user")
                return []
            }
            
            var userVideos = snapshot.documents.compactMap { document -> Video? in
                debugLog("📝 Processing video document: \(document.documentID)")
                guard let video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    debugLog("❌ Failed to parse video document: \(document.documentID)")
                    return nil
                }
                debugLog("✅ Successfully parsed video: \(document.documentID)")
                return video
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
                    .whereField("userId", isEqualTo: userId)
                
                let snapshot = try await query.getDocuments()
                var videos = snapshot.documents.compactMap { Video.fromFirestore($0.data(), id: $0.documentID) }
                videos.sort { $0.createdAt > $1.createdAt }
                return videos
            }
            throw error
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
}