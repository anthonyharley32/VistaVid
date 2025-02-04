import SwiftUI

struct MainView: View {
    @StateObject private var authModel: AuthenticationViewModel
    @State private var selectedTab = 0
    
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
            Text("Record View Coming Soon")
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "camera.circle.fill" : "camera.circle")
                    Text("Record")
                }
                .tag(1)
            
            // Profile Tab
            Text("Profile View Coming Soon")
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.circle.fill" : "person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(.primary)
    }
} 