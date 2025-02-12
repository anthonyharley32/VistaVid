import SwiftUI

// MARK: - Utilities
private func executeWithLogging<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        let result = try await operation()
        print("✅ Operation completed successfully")
        return result
    } catch {
        print("❌ Operation failed: \(error)")
        throw error
    }
}

class VideoFeedViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var videos: [Video] = []
    @Published var hearts: [Heart] = []
    @Published var error: String?
    @Published var isPlaying: Bool = true
    
    init(videos: [Video], startingIndex: Int) {
        self.videos = videos
        self.currentIndex = startingIndex
    }
    
    /// Executes an asynchronous operation with logging
    /// - Parameter operation: The async operation to execute
    /// - Returns: The result of type T from the operation
    /// - Throws: Rethrows any error from the operation
    private func executeWithLogging<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            let result = try await operation()
            print("✅ Operation completed successfully")
            return result
        } catch {
            print("❌ Operation failed: \(error)")
            throw error
        }
    }
    
    func createHeart(at position: CGPoint) {
        Task { @MainActor in
            do {
                try await self.executeWithLogging {
                    let heart = Heart(position: position, rotation: Double.random(in: -45...45))
                    self.hearts.append(heart)
                    
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    self.hearts.removeAll { $0.id == heart.id }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private struct VideoCardContainer: View {
    let video: Video
    let index: Int
    let currentIndex: Int
    let dragOffset: CGFloat
    let onDoubleTap: (CGPoint) -> Void
    let isPlaying: Bool
    let onProfileTap: (String) -> Void
    
    var body: some View {
        VideoCardView(
            video: video,
            isCurrentlyPlaying: .constant(index == currentIndex && isPlaying),
            onDoubleTap: onDoubleTap,
            onProfileTap: onProfileTap
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
        .offset(y: (CGFloat(index - currentIndex) * UIScreen.main.bounds.height) + dragOffset)
    }
}

struct VideoFeedView: View {
    @StateObject private var viewModel: VideoFeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var showUserProfile = false
    @State private var selectedUserId: String?
    
    let title: String
    let onClose: (() -> Void)?
    
    init(
        videos: [Video],
        startingIndex: Int,
        title: String = "",
        onClose: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: VideoFeedViewModel(
            videos: videos,
            startingIndex: startingIndex
        ))
        self.title = title
        self.onClose = onClose
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack {
                        // Videos
                        ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                            if shouldRenderVideo(at: index) {
                                VideoCardContainer(
                                    video: video,
                                    index: index,
                                    currentIndex: viewModel.currentIndex,
                                    dragOffset: dragOffset,
                                    onDoubleTap: { position in
                                        viewModel.createHeart(at: position)
                                    },
                                    isPlaying: viewModel.isPlaying,
                                    onProfileTap: navigateToProfile
                                )
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .transaction { transaction in
                        transaction.animation = isAnimating ? 
                            .interpolatingSpring(stiffness: 200, damping: 25) : nil
                    }
                    .gesture(createDragGesture(geometry: geometry))
                }
                .frame(maxHeight: .infinity)
                .ignoresSafeArea()
                
                // Header
                VStack {
                    HStack {
                        Button(action: {
                            if let onClose = onClose {
                                onClose()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding()
                        }
                        
                        if !title.isEmpty {
                            Text(title)
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        
                        Spacer()
                    }
                    Spacer()
                }
                .zIndex(1)
            }
            .fullScreenCover(isPresented: $showUserProfile) {
                if let userId = selectedUserId {
                    NavigationStack {
                        UserProfileView(userId: userId)
                            .onAppear {
                                viewModel.isPlaying = false
                            }
                    }
                }
            }
            .onAppear {
                viewModel.isPlaying = true
            }
            .onDisappear {
                viewModel.isPlaying = false
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func shouldRenderVideo(at index: Int) -> Bool {
        // Keep 2 videos loaded in each direction for smoother transitions
        abs(index - viewModel.currentIndex) <= 2
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.currentIndex = newIndex
                    dragOffset = 0
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
        return (viewModel.currentIndex == 0 && dragOffset > 0) ||
               (viewModel.currentIndex == viewModel.videos.count - 1 && dragOffset < 0)
    }
    
    func navigateToProfile(_ userId: String) {
        selectedUserId = userId
        showUserProfile = true
    }
}

private enum Constants {
    static let tabBarHeight: CGFloat = 32.0
}

#Preview {
    VideoFeedView(
        videos: [.random(), .random()],
        startingIndex: 0,
        title: "Liked Videos"
    )
} 