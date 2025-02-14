import SwiftUI
import FirebaseAuth
import AVKit

@MainActor
class FYPViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var currentIndex: Int = 0
    @Published var isLoadingMore = false
    @Published var hearts: [Heart] = []
    @Published var error: String?
    @Published var hasReachedEnd = false
    @Published var isPlaying = true
    
    // Pagination and buffering
    private let pageSize = 5
    private let bufferThreshold = 2
    private let maxBufferSize = 10
    private var currentOffset = 0
    private var hasMoreContent = true
    private let videoModel = VideoViewModel()
    
    init() {
        print(" [FYPViewModel] Initialized")
        Task {
            print(" [FYPViewModel] Starting initial load from init")
            await loadInitialVideos()
        }
    }
    
    @MainActor
    public func loadInitialVideos() async {
        print(" [FYPViewModel] Starting loadInitialVideos")
        print(" [FYPViewModel] Current state - videos: \(videos.count), currentIndex: \(currentIndex)")
        
        print(" [FYPViewModel] Calling videoModel.fetchInitialVideos")
        await videoModel.fetchInitialVideos()
        
        print(" [FYPViewModel] VideoModel videos count: \(videoModel.videos.count)")
        
        if videoModel.videos.isEmpty {
            print(" [FYPViewModel] No videos found in database")
            self.error = "No videos to show"
            return
        }
        
        print(" [FYPViewModel] Initial videos loaded: \(videoModel.videos.count)")
        self.videos = videoModel.videos
        currentOffset = videos.count
        hasMoreContent = !videos.isEmpty
        
        print(" [FYPViewModel] Updated state - videos: \(videos.count), currentIndex: \(currentIndex), hasMoreContent: \(hasMoreContent)")
    }
    
    @MainActor
    func loadMoreVideosIfNeeded() async {
        guard shouldLoadMore else {
            print(" [FYPViewModel] Skipping loadMore - shouldLoadMore: false")
            return
        }
        
        print(" [FYPViewModel] Loading more videos")
        print(" [FYPViewModel] Current state - videos: \(videos.count), currentIndex: \(currentIndex)")
        
        isLoadingMore = true
        error = nil
        
        do {
            let currentCount = videos.count
            print(" [FYPViewModel] Calling videoModel.fetchNextBatch")
            await videoModel.fetchNextBatch()
            
            print(" [FYPViewModel] VideoModel videos count after fetch: \(videoModel.videos.count)")
            
            // Get only the new videos
            let newVideos = Array(videoModel.videos.suffix(from: currentCount))
            print(" [FYPViewModel] New videos count: \(newVideos.count)")
            
            if newVideos.isEmpty {
                print(" [FYPViewModel] No more videos available")
                hasMoreContent = false
                hasReachedEnd = true
                isLoadingMore = false
                return
            }
            
            print(" [FYPViewModel] Loaded \(newVideos.count) more videos")
            
            // Update state
            videos.append(contentsOf: newVideos)
            currentOffset += newVideos.count
            hasMoreContent = true
            
            print(" [FYPViewModel] Updated state - videos: \(videos.count), currentOffset: \(currentOffset)")
            
            // Only clean up old videos if we're not near the end
            if hasMoreContent && videos.count > maxBufferSize {
                print(" [FYPViewModel] Starting cleanup")
                cleanupOldVideos()
            }
            
        } catch {
            print(" [FYPViewModel] Error loading more videos: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    private func cleanupOldVideos() {
        guard videos.count > maxBufferSize && !hasReachedEnd else {
            print(" [FYPViewModel] Skipping cleanup - conditions not met")
            return
        }
        
        print(" [FYPViewModel] Cleaning up old videos")
        print(" [FYPViewModel] Before cleanup - videos: \(videos.count), currentIndex: \(currentIndex)")
        
        // Keep current video + buffer ahead and behind
        let keepRange = max(0, currentIndex - 2)...min(videos.count - 1, currentIndex + bufferThreshold)
        videos = Array(videos[keepRange])
        
        // Adjust the current index and offset
        currentOffset -= currentIndex - keepRange.lowerBound
        currentIndex -= keepRange.lowerBound
        
        print(" [FYPViewModel] After cleanup - videos: \(videos.count), currentIndex: \(currentIndex), offset: \(currentOffset)")
    }
    
    private var shouldLoadMore: Bool {
        guard !isLoadingMore && hasMoreContent && !hasReachedEnd else {
            print(" [FYPViewModel] shouldLoadMore: false - isLoadingMore: \(isLoadingMore), hasMoreContent: \(hasMoreContent), hasReachedEnd: \(hasReachedEnd)")
            return false
        }
        
        // Calculate if we're close enough to the end to load more
        let distanceToEnd = videos.count - (currentIndex + 1)
        let shouldLoad = distanceToEnd <= bufferThreshold
        
        print(" [FYPViewModel] shouldLoadMore check - distance to end: \(distanceToEnd), threshold: \(bufferThreshold), should load: \(shouldLoad)")
        
        return shouldLoad
    }
    
    func createHeart(at position: CGPoint) {
        print(" [FYPViewModel] Creating heart at position: \(position)")
        let heart = Heart(position: position, rotation: Double.random(in: -45...45))
        hearts.append(heart)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hearts.removeAll { $0.id == heart.id }
        }
    }
}

struct FYPView: View {
    @StateObject private var viewModel = FYPViewModel()
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Video cards - only render videos in view window
                    ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                        if shouldRenderVideo(at: index) {
                            VideoCardView(
                                video: video,
                                isCurrentlyPlaying: Binding(
                                    get: { index == viewModel.currentIndex && viewModel.isPlaying },
                                    set: { newValue in
                                        viewModel.isPlaying = newValue
                                    }
                                ),
                                onDoubleTap: { position in
                                    viewModel.createHeart(at: position)
                                },
                                onProfileTap: { _ in }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .animation(.easeInOut(duration: 0.25), value: viewModel.currentIndex)
                            .offset(y: (CGFloat(index - viewModel.currentIndex) * geometry.size.height) + dragOffset)
                        }
                    }
                    
                    // Hearts
                    ForEach(viewModel.hearts) { heart in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            .position(heart.position)
                    }
                    
                    // Loading and error states
                    if viewModel.isLoadingMore {
                        VStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                            Spacer().frame(height: 100)
                        }
                    }
                    
                    if let error = viewModel.error {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 50))
                                .symbolVariant(.slash)
                                .foregroundColor(.black)
                            
                            Text(error)
                                .font(.title3)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .zIndex(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .transaction { transaction in
                    transaction.animation = isAnimating ? 
                        .easeInOut(duration: 0.25) : nil
                }
                .gesture(createDragGesture(geometry: geometry))
                .offset(y: -30)
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .task {
                // Only load videos if we haven't loaded any yet
                if viewModel.videos.isEmpty {
                    print(" [FYP] View appeared, starting initial load")
                    await viewModel.loadInitialVideos()
                }
                
                print(" [FYP] Setting up notification observers")
                setupNotificationObservers()
            }
            .onDisappear {
                print(" [FYP] View disappeared, removing observers")
                removeNotificationObservers()
            }
        }
    }
    
    // MARK: - Notification Handling
    @MainActor
    private func setupNotificationObservers() {
        print(" Setting up hands-free mode notification observers in FYPView")
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateVideo"),
            object: nil,
            queue: .main
        ) { [weak viewModel] notification in
            guard let direction = notification.userInfo?["direction"] as? String,
                  let viewModel = viewModel else { return }
            
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    if direction == "previous" && viewModel.currentIndex > 0 {
                        print(" Navigating to previous video")
                        viewModel.currentIndex -= 1
                    } else if direction == "next" && viewModel.currentIndex < viewModel.videos.count - 1 {
                        print(" Navigating to next video")
                        viewModel.currentIndex += 1
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleVideoPlayback"),
            object: nil,
            queue: .main
        ) { [weak viewModel] _ in
            guard let viewModel = viewModel else { return }
            Task { @MainActor in
                print(" Toggling video playback")
                viewModel.isPlaying.toggle()
            }
        }
    }
    
    private func removeNotificationObservers() {
        print(" Removing hands-free mode notification observers from FYPView")
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("NavigateVideo"),
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("ToggleVideoPlayback"),
            object: nil
        )
    }
    
    private func shouldRenderVideo(at index: Int) -> Bool {
        // Keep 2 videos loaded in each direction for smoother transitions
        let shouldRender = abs(index - viewModel.currentIndex) <= 2
        print(" [FYP] Checking if should render video at index \(index): \(shouldRender)")
        return shouldRender
    }
    
    private func createDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { handleDragChange($0, geometry: geometry) }
            .onEnded { handleDragEnd($0, geometry: geometry) }
    }
    
    private func handleDragChange(_ value: DragGesture.Value, geometry: GeometryProxy) {
        guard !isAnimating else { return }
        
        if shouldRestrictDrag() {
            dragOffset = value.translation.height * 0.5
        } else {
            dragOffset = value.translation.height
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value, geometry: GeometryProxy) {
        let velocity = value.predictedEndLocation.y - value.location.y
        let screenHeight = geometry.size.height - Constants.tabBarHeight
        
        isAnimating = true
        
        if ScrollBehaviorManager.shouldMove(offset: dragOffset, velocity: velocity, screenHeight: screenHeight) {
            let newIndex = ScrollBehaviorManager.calculateNewIndex(
                currentIndex: viewModel.currentIndex,
                maxIndex: viewModel.videos.count - 1,
                dragOffset: dragOffset
            )
            
            if newIndex != viewModel.currentIndex {
                print(" [FYP] Changing current index from \(viewModel.currentIndex) to \(newIndex)")
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.currentIndex = newIndex
                    dragOffset = 0
                }
                
                // Only try to load more if we're not at the end
                if !viewModel.hasReachedEnd && newIndex >= viewModel.videos.count - 2 {
                    Task {
                        print(" [FYP] Near end of list, loading more videos")
                        await viewModel.loadMoreVideosIfNeeded()
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    dragOffset = 0
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                dragOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isAnimating = false
        }
    }
    
    private func shouldRestrictDrag() -> Bool {
        let shouldRestrict = (viewModel.currentIndex == 0 && dragOffset > 0) ||
               (viewModel.currentIndex == viewModel.videos.count - 1 && dragOffset < 0)
        if shouldRestrict {
            print(" [FYP] Restricting drag at index \(viewModel.currentIndex)")
        }
        return shouldRestrict
    }
    
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
}

private enum Constants {
    static let tabBarHeight: CGFloat = 32.0
}

#Preview {
    FYPView()
} 