import SwiftUI

struct MainView: View {
    @ObservedObject var authModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @State private var showingCamera = false
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
        // Remove the default tab bar background
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
                
                // Empty tab for spacing
                Color.clear
                    .tabItem {
                        Text("")
                    }
                    .tag(1)
                
                // Profile Tab
                ProfileView(model: authModel)
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(2)
            }
            .tint(.primary)
            
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
            .offset(y: -32) // Move up from tab bar
        }
        .fullScreenCover(isPresented: $showingCamera) {
            RecordingView()
        }
    }
}