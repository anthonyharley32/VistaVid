import SwiftUI

struct MainView: View {
    @ObservedObject var authModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @State private var showingCamera = false
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
        UITabBar.appearance().backgroundColor = .systemBackground
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Feed Tab
                FeedView(authModel: authModel)
                    .tabItem {
                        Label("Feed", systemImage: "play.rectangle.fill")
                    }
                    .tag(0)
                
                // Communities Tab (Empty for now)
                Color.clear
                    .tabItem {
                        Label("Communities", systemImage: "person.3.fill")
                    }
                    .tag(1)
                
                // Empty tab for camera button spacing
                Color.clear
                    .tabItem {
                        Text("")
                    }
                    .tag(2)
                
                // Inbox Tab
                InboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "envelope.fill")
                    }
                    .tag(3)
                
                // Profile Tab
                ProfileView(user: authModel.currentUser ?? User.placeholder, authModel: authModel)
                    .tabItem {
                        Label("You", systemImage: "person.fill")
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
            RecordingView()
        }
    }
}