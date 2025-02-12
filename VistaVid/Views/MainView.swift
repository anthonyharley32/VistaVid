import SwiftUI

struct MainView: View {
    @ObservedObject var authModel: AuthenticationViewModel
    @StateObject private var videoViewModel = VideoViewModel()
    @State private var selectedTab = 0
    @State private var showingCamera = false
    private let communitiesModel = CommunitiesViewModel()
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
        UITabBar.appearance().backgroundColor = .systemBackground
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                PlaceholderFeedView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                CommunitiesView(model: communitiesModel)
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Communities")
                    }
                    .tag(1)
                
                // Empty tab for camera button spacing
                Color.clear
                    .tabItem {
                        Text("")
                    }
                    .tag(2)
                
                InboxView()
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Inbox")
                    }
                    .tag(3)
                
                ProfileView(user: authModel.currentUser ?? User.placeholder, authModel: authModel)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("You")
                    }
                    .tag(4)
            }
            .tint(.primary)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToYouTab"))) { _ in
                selectedTab = 4
            }
            
            // Floating record button
            Button(action: {
                showingCamera = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.primary)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            .offset(y: -10) // Increased offset to have 70% of button overlay the tab bar
        }
        .fullScreenCover(isPresented: $showingCamera) {
            RecordingView(videoViewModel: videoViewModel)
        }
        .ignoresSafeArea(.keyboard) // Prevent keyboard from pushing content up
    }
}

struct PlaceholderFeedView: View {
    var body: some View {
        ContentUnavailableView("No Videos", 
            systemImage: "video.slash",
            description: Text("Videos coming soon!"))
    }
}

#Preview {
    MainView(authModel: AuthenticationViewModel())
}