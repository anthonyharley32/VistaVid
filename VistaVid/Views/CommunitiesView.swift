import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

@Observable final class CommunitiesViewModel {
    // MARK: - Properties
    var searchText = ""
    var users: [User] = []
    var communities: [Community] = []
    var isLoading = false
    var error: Error?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Search Methods
    @MainActor
    func searchUsers() async {
        guard !searchText.isEmpty else {
            users = []
            return
        }
        
        isLoading = true
        error = nil
        debugLog("Starting user search with query: \(searchText)")
        
        do {
            let searchTerm = searchText.lowercased()
            let endTerm = searchTerm.appending("\u{f8ff}")
            
            let query = db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: searchTerm)
                .whereField("username", isLessThan: endTerm)
                .order(by: "username")
                .limit(to: 20)
            
            let snapshot = try await query.getDocuments()
            debugLog("Found \(snapshot.documents.count) users")
            
            users = snapshot.documents.compactMap { document in
                do {
                    var userData = document.data()
                    userData["userId"] = document.documentID
                    return try Firestore.Decoder().decode(User.self, from: userData)
                } catch {
                    debugLog("Error decoding user: \(error)")
                    return nil
                }
            }
        } catch {
            debugLog("User search error: \(error)")
            self.error = error
            users = []
        }
        
        isLoading = false
    }
    
    @MainActor
    func searchCommunities() async {
        guard !searchText.isEmpty else {
            debugLog("🔍 Search text is empty, clearing communities")
            communities = []
            return
        }
        
        isLoading = true
        error = nil
        debugLog("🚀 Starting community search with query: '\(searchText)'")
        debugLog("📊 Current state - isLoading: \(isLoading), error: \(String(describing: error))")
        
        do {
            let searchTerm = searchText.lowercased()
            debugLog("🔤 Lowercase search term: '\(searchTerm)'")
            debugLog("🎯 Building query for communities collection")
            
            // Query for communities where name starts with the search term
            let query = db.collection("communities")
                .whereField("name", isGreaterThanOrEqualTo: searchText)
                .whereField("name", isLessThanOrEqualTo: searchText + "\u{f8ff}")
                .order(by: "name")
                .limit(to: 20)
            
            debugLog("📬 Executing Firestore query...")
            let snapshot = try await query.getDocuments()
            debugLog("📥 Found \(snapshot.documents.count) communities in Firestore")
            
            if snapshot.documents.isEmpty {
                debugLog("❌ No communities found in initial query")
            } else {
                debugLog("📋 Retrieved communities:")
                for doc in snapshot.documents {
                    let data = doc.data()
                    debugLog("  - ID: \(doc.documentID)")
                    debugLog("    Name: \(data["name"] as? String ?? "unknown")")
                    debugLog("    Creator: \(data["creatorId"] as? String ?? "unknown")")
                    debugLog("    Members: \(data["membersCount"] as? Int ?? 0)")
                }
            }
            
            debugLog("🔄 Processing and filtering results...")
            var processedCount = 0
            var failedCount = 0
            
            communities = snapshot.documents.compactMap { document in
                processedCount += 1
                debugLog("📄 Processing document \(processedCount)/\(snapshot.documents.count)")
                
                guard let community = Community.fromFirestore(document.data(), id: document.documentID) else {
                    failedCount += 1
                    debugLog("⚠️ Failed to parse community document: \(document.documentID)")
                    return nil
                }
                
                let matches = community.name.lowercased().contains(searchTerm)
                debugLog("🎯 Filtering community '\(community.name)'")
                debugLog("  - Original name: '\(community.name)'")
                debugLog("  - Lowercase name: '\(community.name.lowercased())'")
                debugLog("  - Search term: '\(searchTerm)'")
                debugLog("  - Matches: \(matches)")
                return matches ? community : nil
            }
            
            debugLog("📊 Search Results Summary:")
            debugLog("  - Total documents: \(snapshot.documents.count)")
            debugLog("  - Processed: \(processedCount)")
            debugLog("  - Failed to parse: \(failedCount)")
            debugLog("  - Final results: \(communities.count) communities")
            
            if !communities.isEmpty {
                debugLog("✅ Found communities:")
                communities.forEach { community in
                    debugLog("  - \(community.name) (ID: \(community.id))")
                }
            }
            
        } catch {
            self.error = error
            communities = []
        }
        
        isLoading = false
        debugLog("🏁 Search completed - isLoading: \(isLoading), results: \(communities.count)")
    }
    
    // MARK: - Debug
    func debugLog(_ message: String) {
        print("CommunitiesView Debug: \(message)")
    }
}

struct CommunityImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CommunityImagePicker

        init(_ parent: CommunityImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}

struct ColorCircleView: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
            )
            .onTapGesture(perform: action)
    }
}

struct ColorPickerView: View {
    @Binding var backgroundColor: Color
    let colors: [Color]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    ColorCircleView(
                        color: color,
                        isSelected: backgroundColor == color,
                        action: { backgroundColor = color }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct EmojiGridView: View {
    @Binding var selectedEmoji: String
    let backgroundColor: Color
    let emojis: [String]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(width: 44, height: 44)
                        .background(selectedEmoji == emoji ? backgroundColor.opacity(0.3) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedEmoji == emoji ? backgroundColor : .clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedEmoji = emoji
                        }
                }
            }
            .padding()
        }
    }
}

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    @Binding var backgroundColor: Color
    
    // Common emojis for communities
    private let emojis = [
        "👥", "🌟", "🎮", "📚", "🎨", "🎭", "🎬", "🎵", "🎸", "🎹",
        "⚽️", "🏀", "🎾", "🏈", "⚾️", "🎱", "🎳", "🏓", "🎯", "🎲",
        "🌍", "🌎", "🌏", "🗺️", "🌄", "🌅", "🌇", "🌆", "🏰", "🎡",
        "🎪", "🎢", "🎠", "🏟️", "🏯", "🏭", "🏬", "🏫", "🏪", "🏩",
        "💻", "📱", "🖥️", "⌨️", "🖱️", "🖨️", "📷", "🎥", "📹", "🎦",
        "🎭", "🎨", "🎪", "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎺",
        "🧩", "🎲", "🎯", "🎳", "🎮", "🎰", "🎱", "🔮", "🎨", "🎭",
        "🍕", "🍔", "🌮", "🌯", "🍜", "🍣", "🍱", "🥗", "🍪", "🍩"
    ]
    
    // Predefined background colors
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .teal, .cyan, .blue, .indigo, .purple,
        .pink, .brown, .gray
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ColorPickerView(backgroundColor: $backgroundColor, colors: colors)
                EmojiGridView(selectedEmoji: $selectedEmoji, backgroundColor: backgroundColor, emojis: emojis)
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CreateCommunityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var communityName = ""
    @State private var description = ""
    @State private var showImagePicker = false
    @State private var showEmojiPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedEmoji = "👥"
    @State private var backgroundColor = Color.blue
    @State private var useEmoji = true
    @State private var isLoading = false
    @State private var error: Error?
    @ObservedObject var communityModel: CommunityViewModel
    private let storage = Storage.storage()
    
    // Validation
    private var isFormValid: Bool {
        !communityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (useEmoji || selectedImage != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Community Name", text: $communityName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    ZStack(alignment: .leading) {
                        if description.isEmpty {
                            Text("Description")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    }
                }
                
                Section("Community Icon") {
                    Picker("Icon Type", selection: $useEmoji) {
                        Text("Emoji").tag(true)
                        Text("Image").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                    
                    if useEmoji {
                        Button(action: { showEmojiPicker = true }) {
                            HStack {
                                Text("Selected Icon")
                                Spacer()
                                Text(selectedEmoji)
                                    .font(.system(size: 30))
                                    .frame(width: 44, height: 44)
                                    .background(backgroundColor.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    } else {
                        Button(action: { showImagePicker = true }) {
                            HStack {
                                Text(selectedImage == nil ? "Select Image" : "Change Image")
                                Spacer()
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "photo.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createCommunity()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                    .opacity(isFormValid && !isLoading ? 1 : 0.5)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                CommunityImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedEmoji, backgroundColor: $backgroundColor)
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }
        }
    }
    
    private func createCommunity() async {
        guard isFormValid else { return }
        isLoading = true
        
        do {
            var iconImageUrl: String? = nil
            
            // Upload image if using custom image
            if !useEmoji, let imageData = selectedImage?.jpegData(compressionQuality: 0.7) {
                let storageRef = storage.reference()
                let imagePath = "community_logos/\(UUID().uuidString).jpg"
                let imageRef = storageRef.child(imagePath)
                
                // Add metadata
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                // Upload with metadata
                _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                iconImageUrl = try await imageRef.downloadURL().absoluteString
            }
            
            // Create community with image URL if uploaded
            try await communityModel.createCommunity(
                name: communityName,
                description: description,
                iconType: useEmoji ? "emoji" : "image",
                iconEmoji: useEmoji ? selectedEmoji : nil,
                iconImageUrl: iconImageUrl,
                backgroundColor: backgroundColor.toHex()
            )
            dismiss()
        } catch {
            self.error = error
            // TODO: Show error alert
        }
        
        isLoading = false
    }
    
    private func debugLog(_ message: String) {
        print("CreateCommunityView Debug: \(message)")
    }
}

extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

struct CommunitiesView: View {
    // MARK: - Properties
    let model: CommunitiesViewModel
    @State private var selectedTab = 0
    @State private var showCreateCommunity = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding()
                    .background(Color(.systemBackground))
                
                // Tab Selector
                HStack(spacing: 0) {
                    ForEach(["Users", "Communities"], id: \.self) { tab in
                        Button(action: { 
                            withAnimation { selectedTab = tab == "Users" ? 0 : 1 }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: tab == "Users" ? "person.fill" : "person.3.fill")
                                    .font(.system(size: 20))
                                Rectangle()
                                    .fill(selectedTab == (tab == "Users" ? 0 : 1) ? Color.primary : Color.clear)
                                    .frame(height: 2)
                            }
                            .foregroundColor(selectedTab == (tab == "Users" ? 0 : 1) ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Results
                ZStack {
                    if model.isLoading {
                        ProgressView()
                    } else if let error = model.error {
                        ContentUnavailableView("Error", 
                            systemImage: "exclamationmark.triangle",
                            description: Text(error.localizedDescription))
                    } else if selectedTab == 0 {
                        // Users tab
                        if model.users.isEmpty && !model.searchText.isEmpty {
                            ContentUnavailableView("No Users Found", 
                                systemImage: "person.slash",
                                description: Text("Try searching with a different term"))
                        } else {
                            usersList
                        }
                    } else {
                        // Communities tab
                        if model.communities.isEmpty && !model.searchText.isEmpty {
                            ContentUnavailableView("No Communities Found", 
                                systemImage: "person.3.slash",
                                description: Text("Try searching with a different term"))
                        } else {
                            communitiesList
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .toolbar {
                if selectedTab == 1 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCreateCommunity = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18))
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateCommunity) {
                CreateCommunityView(communityModel: CommunityViewModel())
            }
        }
    }
    
    // MARK: - Components
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField(selectedTab == 0 ? "Search users..." : "Search communities...", 
                     text: Binding(
                        get: { model.searchText },
                        set: { model.searchText = $0 }
                     ))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .onChange(of: model.searchText) { oldValue, newValue in
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if selectedTab == 0 {
                        await model.searchUsers()
                    } else {
                        await model.searchCommunities()
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                model.searchText = ""
                model.users = []
                model.communities = []
            }
            
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                    model.users = []
                    model.communities = []
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
    
    private var communitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(model.communities) { community in
                    Button(action: {
                        // TODO: Navigate to community detail view
                    }) {
                        HStack(spacing: 12) {
                            if community.iconType == "emoji" {
                                Text(community.displayIcon)
                                    .font(.system(size: 30))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: community.backgroundColor ?? "#007AFF")?.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if let imageUrl = community.iconImageUrl {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Text(community.displayIcon)
                                        .font(.system(size: 30))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(community.name)
                                    .font(.headline)
                                Text("\(community.membersCount) members")
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

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    CommunitiesView(model: CommunitiesViewModel())
}