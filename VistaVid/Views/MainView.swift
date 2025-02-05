import SwiftUI

struct MainView: View {
    @ObservedObject var authModel: AuthenticationViewModel
    @State private var selectedTab = 0
    @State private var showingCamera = false
    
    init(authModel: AuthenticationViewModel) {
        self.authModel = authModel
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Feed Tab
            FeedView(authModel: authModel)
                .tabItem {
                    Label("Feed", systemImage: "play.rectangle.fill")
                }
                .tag(0)
            
            // Record Tab
            Button(action: {
                showingCamera = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
            }
            .tabItem {
                Label("Record", systemImage: "plus.circle.fill")
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
        .sheet(isPresented: $showingCamera) {
            RecordingView()
        }
    }
} 