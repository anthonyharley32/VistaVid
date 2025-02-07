import SwiftUI
import FirebaseFirestore

@Observable final class CommunitiesViewModel {
    // MARK: - Properties
    var searchText = ""
    var users: [User] = []
    var isLoading = false
    private let db = Firestore.firestore()
    
    // MARK: - Search Methods
    @MainActor
    func searchUsers() async {
        guard !searchText.isEmpty else {
            users = []
            return
        }
        
        isLoading = true
        debugLog("Searching for users with query: \(searchText)")
        
        do {
            let searchTextLower = searchText.lowercased()
            let query = db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: searchTextLower)
                .whereField("username", isLessThan: searchTextLower + "z")
                .limit(to: 20)
            
            let snapshot = try await query.getDocuments()
            users = snapshot.documents.compactMap { document in
                try? document.data(as: User.self)
            }
            debugLog("Found \(users.count) users")
        } catch {
            debugLog("Error searching users: \(error.localizedDescription)")
            users = []
        }
        
        isLoading = false
    }
    
    // MARK: - Debug
    func debugLog(_ message: String) {
        print("CommunitiesView Debug: \(message)")
    }
}

struct CommunitiesView: View {
    // MARK: - Properties
    let model: CommunitiesViewModel
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar - fixed position
                searchBar
                    .padding()
                    .background(Color(.systemBackground))
                
                // Results in scrollable area
                ZStack {
                    if model.isLoading {
                        ProgressView()
                    } else if model.users.isEmpty && !model.searchText.isEmpty {
                        ContentUnavailableView("No Users Found", 
                            systemImage: "person.slash",
                            description: Text("Try searching with a different term"))
                    } else {
                        usersList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Search Users")
        }
    }
    
    // MARK: - Components
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search users...", text: Binding(
                get: { model.searchText },
                set: { model.searchText = $0 }
            ))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .onChange(of: model.searchText) { oldValue, newValue in
                // Debounce search
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await model.searchUsers()
                }
            }
            
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                    model.users = []
                    model.debugLog("Search text cleared")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
        }
    }
    
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(model.users) { user in
                    NavigationLink(destination: ProfileView(user: user, authModel: AuthenticationViewModel())) {
                        HStack(spacing: 12) {
                            // Profile Image
                            AsyncImage(url: URL(string: user.profilePicUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            // User Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.headline)
                                
                                Text("\(user.followersCount) followers")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    CommunitiesView(model: CommunitiesViewModel())
}