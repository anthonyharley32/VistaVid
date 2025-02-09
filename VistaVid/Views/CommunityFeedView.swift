import SwiftUI
import FirebaseFirestore

private struct AuthModelKey: EnvironmentKey {
    static let defaultValue: AuthenticationViewModel? = nil
}

extension EnvironmentValues {
    var authModel: AuthenticationViewModel? {
        get { self[AuthModelKey.self] }
        set { self[AuthModelKey.self] = newValue }
    }
}

struct CommunityFeedView: View {
    let community: Community
    @Environment(\.videoViewModel) private var videoViewModel
    @Environment(\.authModel) private var authModel
    @Environment(\.videoPlayerManager) private var videoManager
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var currentIndex: Int?
    @State private var visibleIndex: Int?
    @State private var selectedUser: User?
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if videos.isEmpty {
                ContentUnavailableView("No Videos", 
                    systemImage: "video.slash",
                    description: Text("Be the first to post in this community!"))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(videos.enumerated()), id: \.element.id) { (index: Int, video: Video) in
                            VideoPlayerView(
                                video: video,
                                index: index,
                                videoManager: videoManager,
                                isVisible: visibleIndex == index,
                                onUserTap: { handleUserTap(video: video) }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .onAppear {
                                print("📱 [CommunityFeedView]: Video \(index) appeared")
                                if currentIndex == nil {
                                    currentIndex = index
                                    visibleIndex = index
                                }
                            }
                            .modifier(VisibilityModifier(index: index, currentVisibleIndex: $visibleIndex))
                            .onDisappear {
                                print("📱 [CommunityFeedView]: Video \(index) disappeared")
                            }
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentIndex)
                .onChange(of: visibleIndex) { oldValue, newValue in
                    print("📱 [CommunityFeedView]: Visible index changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                    if let index = newValue {
                        videoManager.pauseAllExcept(index: index)
                    } else {
                        videoManager.cleanup()
                    }
                }
                .onDisappear {
                    videoManager.cleanup()
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadCommunityVideos()
        }
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(user: user)
        }
    }
    
    private func loadCommunityVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var loadedVideos = try await videoViewModel.fetchCommunityVideos(communityId: community.id)
            
            // Fetch user data for each video
            for i in 0..<loadedVideos.count {
                loadedVideos[i].user = await videoViewModel.fetchUserForVideo(loadedVideos[i])
            }
            
            videos = loadedVideos
        } catch {
            print("Error loading community videos: \(error)")
        }
    }
    
    private func handleUserTap(video: Video) {
        if video.user?.id == authModel?.currentUser?.id {
            print("📱 [CommunityFeedView]: Navigating to You tab")
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToYouTab"), object: nil)
        } else {
            print("📱 [CommunityFeedView]: Navigating to UserProfileView")
            selectedUser = video.user
        }
    }
} 