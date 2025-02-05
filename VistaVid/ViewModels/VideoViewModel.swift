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
            
            // Upload video data
            debugLog("📤 Starting video file upload")
            let videoData = try Data(contentsOf: videoURL)
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            debugLog("📤 Uploading to Firebase Storage...")
            _ = try await videoRef.putDataAsync(videoData, metadata: metadata)
            debugLog("✅ Video file uploaded successfully")
            
            let videoDownloadURL = try await videoRef.downloadURL()
            debugLog("🔗 Video download URL: \(videoDownloadURL.absoluteString)")
            
            // Generate and upload thumbnail
            debugLog("🖼️ Generating thumbnail")
            if let thumbnailData = try await generateThumbnail(from: videoURL) {
                let thumbnailRef = storage.child("thumbnails/\(videoId).jpg")
                debugLog("📤 Uploading thumbnail")
                _ = try await thumbnailRef.putDataAsync(thumbnailData)
                debugLog("✅ Thumbnail uploaded successfully")
            }
            
            // Create video document
            debugLog("📝 Creating Firestore document")
            let video = Video(
                id: videoId,
                userId: currentUser.uid,
                videoUrl: videoDownloadURL.absoluteString,
                thumbnailUrl: nil, // TODO: Add thumbnail URL
                description: description,
                createdAt: Date(),
                algorithmTags: algorithmTags
            )
            
            // Save to Firestore
            try await db.collection("videos").document(videoId).setData(video.toDictionary())
            debugLog("✅ Video document created in Firestore")
            debugLog("🎉 Upload process completed successfully")
            
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
            print("📱 [VideoViewModel]: Querying Firestore")
            let snapshot = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: batchSize)
                .getDocuments()
            
            print("📱 [VideoViewModel]: Found \(snapshot.documents.count) documents")
            
            let newVideos = snapshot.documents.compactMap { (document: QueryDocumentSnapshot) -> Video? in
                print("📱 [VideoViewModel]: Processing document \(document.documentID)")
                print("📱 [VideoViewModel]: Document data: \(document.data())")
                
                guard let video = Video.fromFirestore(document.data(), id: document.documentID) else {
                    print("📱 [VideoViewModel]: Failed to parse document \(document.documentID)")
                    return nil
                }
                print("📱 [VideoViewModel]: Successfully parsed video \(video.id)")
                return video
            }
            
            await MainActor.run {
                self.videos = newVideos
                self.lastDocument = snapshot.documents.last
                print("📱 [VideoViewModel]: Successfully loaded \(newVideos.count) videos")
            }
        } catch {
            print("📱 [VideoViewModel]: Error loading videos: \(error)")
            print("📱 [VideoViewModel]: Detailed error: \(String(describing: error))")
            self.error = error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates a thumbnail from a video URL
    private func generateThumbnail(from videoURL: URL) async throws -> Data? {
        debugLog("🖼️ Starting thumbnail generation")
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get thumbnail at 0 seconds
        debugLog("🖼️ Generating thumbnail frame")
        let cgImage = try await imageGenerator.image(at: .zero).image
        
        // Convert to UIImage and then to Data
        let thumbnail = UIImage(cgImage: cgImage)
        let data = thumbnail.jpegData(compressionQuality: 0.7)
        debugLog("🖼️ Thumbnail generated: \(data?.count ?? 0) bytes")
        return data
    }
    
    /// Debug logging
    private func debugLog(_ message: String) {
        if debug {
            print("🎥 [Video]: \(message)")
        }
    }
} 