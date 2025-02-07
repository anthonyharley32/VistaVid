import SwiftUI
import FirebaseFirestore

@Observable final class CommunitiesViewModel {
    // MARK: - Properties
    var searchText = ""
    var users: [User] = []
    var isLoading = false
    var error: Error?
    private let db = Firestore.firestore()
    
    // MARK: - Search Methods
    @MainActor
    func searchUsers() async {
        guard !searchText.isEmpty else {
            users = []
            return
        }
        
        isLoading = true
        error = nil
        debugLog("Starting search with query: \(searchText)")
        
        do {
            // Create search keywords
            let searchTerms = searchText.lowercased().split(separator: " ")
            debugLog("Search terms after processing: \(searchTerms)")
            
            // Build query
            let usersRef = db.collection("users")
            let baseQuery: Query
            
            // For debugging: First get all users to verify data
            debugLog("Fetching all users for debug...")
            let allUsers = try await usersRef.getDocuments()
            debugLog("Total users in database: \(allUsers.documents.count)")
            if let firstUser = allUsers.documents.first?.data() {
                debugLog("Sample user data: \(firstUser)")
            }
            
            // If search has multiple terms, use array contains for keywords
            if searchTerms.count > 1 {
                debugLog("Using multi-term search strategy")
                baseQuery = usersRef.whereField("searchKeywords", arrayContainsAny: searchTerms.map(String.init))
            } else {
                // For single term, use efficient prefix search
                let searchTerm = String(searchTerms[0]).lowercased() // Convert to lowercase to match stored format
                let endTerm = searchTerm.appending("\u{f8ff}")
                debugLog("Using single-term search strategy")
                debugLog("Search range: from '\(searchTerm)' to '\(endTerm)'")
                
                baseQuery = usersRef
                    .whereField("username", isGreaterThanOrEqualTo: searchTerm)
                    .whereField("username", isLessThan: endTerm)
            }
            
            // Add ordering and limit
            let finalQuery = baseQuery
                .order(by: "username")
                .limit(to: 20)
            
            debugLog("Executing search query...")
            let snapshot = try await finalQuery.getDocuments()
            debugLog("Query returned \(snapshot.documents.count) documents")
            
            users = snapshot.documents.compactMap { document in
                do {
                    // Create a dictionary with the ID included
                    var userData = document.data()
                    userData["userId"] = document.documentID  // Add document ID as userId
                    debugLog("Processing user document: \(document.documentID) with data: \(userData)")
                    
                    let user = try Firestore.Decoder().decode(User.self, from: userData)
                    debugLog("Successfully decoded user: \(user.username)")
                    return user
                } catch {
                    debugLog("Error decoding user document \(document.documentID): \(error)")
                    debugLog("Detailed error: \(String(describing: error))")
                    return nil
                }
            }
            
            debugLog("Final processed users count: \(users.count)")
            
        } catch {
            debugLog("Search error: \(error.localizedDescription)")
            debugLog("Detailed error: \(error)")
            self.error = error
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
                    } else if let error = model.error {
                        ContentUnavailableView("Error", 
                            systemImage: "exclamationmark.triangle",
                            description: Text(error.localizedDescription))
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