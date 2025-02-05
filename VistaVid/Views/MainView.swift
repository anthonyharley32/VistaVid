import SwiftUI

struct MainView: View {
    @StateObject private var authModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @State private var showingCamera = false
    
    init(authModel: AuthenticationViewModel) {
        _authModel = StateObject(wrappedValue: authModel)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Feed Tab
            FeedView(authModel: authModel)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "play.circle.fill" : "play.circle")
                    Text("Feed")
                }
                .tag(0)
            
            // Record Tab
            Button(action: {
                showingCamera = true
            }) {
                Color.black
                    .overlay(
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "camera.circle.fill" : "camera.circle")
                Text("Record")
            }
            .tag(1)
            
            // Profile Tab
            ProfileView(model: authModel)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.circle.fill" : "person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(.primary)
        .fullScreenCover(isPresented: $showingCamera) {
            RecordingView()
        }
    }
} 