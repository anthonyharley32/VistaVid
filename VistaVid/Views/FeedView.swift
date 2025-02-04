import SwiftUI
import AVKit

struct FeedView: View {
    // MARK: - Properties
    @ObservedObject var authModel: AuthenticationViewModel
    @StateObject private var videoModel = VideoViewModel()
    @State private var currentVideoIndex = 0
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color.black.edgesIgnoringSafeArea(.all)
                
                if videoModel.isLoading && videoModel.videos.isEmpty {
                    // Loading state
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if videoModel.videos.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Videos Yet")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Videos you upload will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    // Video feed
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(videoModel.videos) { video in
                                VideoPlayerView(video: video)
                                    .frame(height: UIScreen.main.bounds.height)
                                    .onAppear {
                                        // Load more videos when reaching end
                                        if video.id == videoModel.videos.last?.id {
                                            Task {
                                                await videoModel.fetchNextBatch()
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load initial videos
                await videoModel.fetchInitialVideos()
            }
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    let video: Video
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        isPlaying = true
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                // Thumbnail or loading state
                Color.black
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            // Video controls overlay
            VStack {
                Spacer()
                
                // Video info
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.description)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                        
                        // Algorithm tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(video.algorithmTags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Interaction buttons
                    VStack(spacing: 20) {
                        Button(action: { /* Like action */ }) {
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 28))
                                Text("\(video.likesCount)")
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { /* Comment action */ }) {
                            VStack {
                                Image(systemName: "bubble.right.fill")
                                    .font(.system(size: 28))
                                Text("\(video.commentsCount)")
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { /* Share action */ }) {
                            VStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .font(.system(size: 28))
                                Text("\(video.sharesCount)")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.trailing)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Initialize player when view appears
            if player == nil {
                player = AVPlayer(url: URL(string: video.videoUrl)!)
            }
        }
    }
} 