import Foundation
import FirebaseFirestore
import FirebaseStorage
import AVFoundation

@MainActor
final class VideoViewModel: ObservableObject {
    // MARK: - Properties
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastVisible: DocumentSnapshot?
    
    // Batch size for pagination
    private let batchSize = 10
    
    // MARK: - Debug Properties
    private let debug = true
    
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
            
            lastVisible = snapshot.documents.last
            debugLog("✅ Successfully fetched initial videos")
            
        } catch {
            debugLog("❌ Error fetching videos: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Fetches the next batch of videos for infinite scrolling
    func fetchNextBatch() async {
        guard let lastVisible = lastVisible else {
            debugLog("ℹ️ No more videos to fetch")
            return
        }
        
        debugLog("🎬 Fetching next batch of videos")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = db.collection("videos")
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastVisible)
                .limit(to: batchSize)
            
            let snapshot = try await query.getDocuments()
            debugLog("📄 Got \(snapshot.documents.count) more videos")
            
            let mappedVideos = snapshot.documents.map { document in
                Video.fromFirestore(document.data(), id: document.documentID)
            }
            let newVideos = mappedVideos.compactMap { $0 }
            
            videos.append(contentsOf: newVideos)
            self.lastVisible = snapshot.documents.last
            debugLog("✅ Successfully fetched next batch")
            
        } catch {
            debugLog("❌ Error fetching next batch: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Uploads a new video
    func uploadVideo(videoURL: URL, description: String, algorithmTags: [String]) async throws {
        debugLog("📤 Starting video upload")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Generate a unique ID for the video
            let videoId = UUID().uuidString
            
            // Create storage reference
            let videoRef = storage.child("videos/\(videoId).mp4")
            
            // Upload video data
            let videoData = try Data(contentsOf: videoURL)
            _ = try await videoRef.putDataAsync(videoData)
            let videoDownloadURL = try await videoRef.downloadURL()
            
            // Generate and upload thumbnail
            if let thumbnailData = try await generateThumbnail(from: videoURL),
               let thumbnailImage = UIImage(data: thumbnailData) {
                let thumbnailRef = storage.child("thumbnails/\(videoId).jpg")
                if let thumbnailJPEG = thumbnailImage.jpegData(compressionQuality: 0.7) {
                    _ = try await thumbnailRef.putDataAsync(thumbnailJPEG)
                }
            }
            
            // Create video document
            let video = Video(
                id: videoId,
                userId: "currentUserId", // TODO: Get from AuthViewModel
                videoUrl: videoDownloadURL.absoluteString,
                thumbnailUrl: nil, // TODO: Add thumbnail URL
                description: description,
                algorithmTags: algorithmTags
            )
            
            // Save to Firestore
            try await db.collection("videos").document(videoId).setData(video.toDictionary())
            debugLog("✅ Successfully uploaded video")
            
        } catch {
            debugLog("❌ Error uploading video: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates a thumbnail from a video URL
    private func generateThumbnail(from videoURL: URL) async throws -> Data? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get thumbnail at 0 seconds
        let cgImage = try await imageGenerator.image(at: .zero).image
        
        // Convert to UIImage and then to Data
        let thumbnail = UIImage(cgImage: cgImage)
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
    
    /// Debug logging
    private func debugLog(_ message: String) {
        if debug {
            print("🎥 [Video]: \(message)")
        }
    }
} 