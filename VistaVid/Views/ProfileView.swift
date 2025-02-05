import SwiftUI
import FirebaseAuth
import UIKit  // For UIImage type

struct ProfileView: View {
    @ObservedObject var model: AuthenticationViewModel
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header Section
                Section {
                    ProfileHeaderView(model: model)
                }
                
                // Content Rules
                Section {
                    ContentRulesView()
                } header: {
                    Text("Content Rules")
                } footer: {
                    Text("Create custom rules to personalize your feed")
                }
                
                // Account Settings
                Section("Account Settings") {
                    BusinessAccountToggle(model: model, showingAlert: $showingAlert, alertMessage: $alertMessage)
                }
                
                // Sign Out Button
                Section {
                    SignOutButton(model: model, showingAlert: $showingAlert, alertMessage: $alertMessage)
                }
            }
            .navigationTitle("Profile")
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    @ObservedObject var model: AuthenticationViewModel
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUpdatingProfilePic = false
    @State private var isEditingProfile = false
    @State private var editedUsername = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image Button - Contained in its own ZStack for isolation
            ZStack {
                Color.clear // Prevents touch events from propagating
                ProfileImageButton(
                    profilePicUrl: model.currentUser?.profilePicUrl,
                    isUpdatingProfilePic: $isUpdatingProfilePic,
                    showingImagePicker: $showingImagePicker
                )
            }
            .frame(width: 80, height: 80)
            
            // User Info - Now in its own container with clear background
            VStack(alignment: .leading) {
                UserInfoView(
                    model: model,
                    isEditingProfile: $isEditingProfile,
                    editedUsername: $editedUsername,
                    showingAlert: $showingAlert,
                    alertMessage: $alertMessage
                )
            }
            .padding(.leading, 4)
            .background(Color.clear)
            
            Spacer()
        }
        .padding(.vertical)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            guard let image = newValue else { return }
            uploadProfilePicture(image)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func uploadProfilePicture(_ image: UIImage) {
        print("📸 Starting profile picture upload...")
        isUpdatingProfilePic = true
        
        Task {
            do {
                try await model.updateProfilePicture(image)
                print("✅ Profile picture updated successfully")
            } catch {
                print("❌ Failed to update profile picture: \(error)")
                alertMessage = "Failed to update profile picture: \(error.localizedDescription)"
                showingAlert = true
            }
            selectedImage = nil
            isUpdatingProfilePic = false
        }
    }
}

// MARK: - Profile Image Button
struct ProfileImageButton: View {
    let profilePicUrl: String?
    @Binding var isUpdatingProfilePic: Bool
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        Button(action: { showingImagePicker = true }) {
            ZStack {
                if let profilePicUrl = profilePicUrl,
                   let url = URL(string: profilePicUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure(_):
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                
                // Edit overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(4)
                
                if isUpdatingProfilePic {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Prevents button styling from affecting touch area
        .contentShape(Circle()) // Explicitly set the touch area to the circle
    }
}

// MARK: - User Info View
struct UserInfoView: View {
    @ObservedObject var model: AuthenticationViewModel
    @Binding var isEditingProfile: Bool
    @Binding var editedUsername: String
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    @State private var isUpdating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditingProfile {
                HStack {
                    TextField("Username", text: $editedUsername)
                        .font(.headline)
                        .textContentType(.username)
                        .submitLabel(.done)
                        .disabled(isUpdating)
                    
                    if isUpdating {
                        ProgressView()
                            .padding(.horizontal, 8)
                    } else {
                        Button(action: updateUsername) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Button(action: { isEditingProfile = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            } else {
                HStack {
                    Text(model.currentUser?.username ?? "Username")
                        .font(.headline)
                    Button(action: {
                        editedUsername = model.currentUser?.username ?? ""
                        isEditingProfile = true
                    }) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            Text(model.currentUser?.email ?? "Email")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private func updateUsername() {
        guard !editedUsername.isEmpty else {
            alertMessage = "Username cannot be empty"
            showingAlert = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                try await model.updateUsername(editedUsername)
                isEditingProfile = false
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            isUpdating = false
        }
    }
}

// MARK: - Business Account Toggle
struct BusinessAccountToggle: View {
    @ObservedObject var model: AuthenticationViewModel
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        Toggle("Business Account", isOn: Binding(
            get: { model.currentUser?.isBusiness ?? false },
            set: { newValue in
                Task {
                    do {
                        try await model.updateBusinessStatus(newValue)
                    } catch {
                        alertMessage = error.localizedDescription
                        showingAlert = true
                    }
                }
            }
        ))
    }
}

// MARK: - Sign Out Button
struct SignOutButton: View {
    @ObservedObject var model: AuthenticationViewModel
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        Button("Sign Out", role: .destructive) {
            do {
                try model.signOut()
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}

struct AlgorithmRuleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Content Rules")
                .font(.headline)
                .foregroundColor(.gray)
            
            // Example preset rules
            VStack(spacing: 12) {
                RuleCard(
                    title: "AI Learning",
                    description: "Show me AI tools, ML Core tutorials, and productivity hacks",
                    isActive: true
                )
                
                RuleCard(
                    title: "Workout Time",
                    description: "Focus on HIIT workouts and strength training demos",
                    isActive: false
                )
                
                // Add Rule Button
                Button(action: { /* Placeholder */ }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Rule")
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

// Individual rule card
struct RuleCard: View {
    let title: String
    let description: String
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(isActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Content Rules View
struct ContentRulesView: View {
    // Debug: Track rules state changes
    @State private var rules: [ContentRule] = [
        ContentRule(
            title: "AI Learning",
            description: "Teach me about AI and the newest tools like ML Core, Cursor tips, and other productivity tools",
            isActive: true,
            emoji: "🤖"
        ),
        ContentRule(
            title: "Workout Mode",
            description: "Show me HIIT workouts and strength training content between 5-15 minutes",
            isActive: false,
            emoji: "💪"
        )
    ]
    @State private var showingAddRule = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable rules list
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    ForEach(rules) { rule in
                        ContentRuleCard(rule: rule)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Add Rule Button - Pinned at bottom
            VStack {
                Button(action: { showingAddRule = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add New Rule")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemBackground))
        }
        .sheet(isPresented: $showingAddRule) {
            AddRuleView(isPresented: $showingAddRule)
        }
    }
}

// MARK: - Content Rule Card View
struct ContentRuleCard: View {
    let rule: ContentRule
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rule.emoji)
                    .font(.title2)
                Text(rule.title)
                    .font(.headline)
                Spacer()
                Toggle("", isOn: .constant(rule.isActive))
                    .labelsHidden()
            }
            
            Text(rule.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Button(action: { isEditing = true }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                Spacer()
                Button(action: { /* Delete action */ }) {
                    Label("Delete", systemImage: "trash")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $isEditing) {
            EditRuleView(rule: rule, isPresented: $isEditing)
        }
    }
}

struct ContentRule: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var isActive: Bool
    var emoji: String
}

struct AddRuleView: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var selectedEmoji = "📱"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    // Emoji Picker (simplified)
                    Picker("Icon", selection: $selectedEmoji) {
                        ForEach(["📱", "🤖", "💪", "🎨", "📚", "🎮", "🎵"], id: \.self) { emoji in
                            Text(emoji)
                        }
                    }
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Add rule logic would go here
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct EditRuleView: View {
    let rule: ContentRule
    @Binding var isPresented: Bool
    @State private var title: String
    @State private var description: String
    @State private var selectedEmoji: String
    
    init(rule: ContentRule, isPresented: Binding<Bool>) {
        self.rule = rule
        self._isPresented = isPresented
        self._title = State(initialValue: rule.title)
        self._description = State(initialValue: rule.description)
        self._selectedEmoji = State(initialValue: rule.emoji)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    // Emoji Picker (simplified)
                    Picker("Icon", selection: $selectedEmoji) {
                        ForEach(["📱", "🤖", "💪", "🎨", "📚", "🎮", "🎵"], id: \.self) { emoji in
                            Text(emoji)
                        }
                    }
                }
            }
            .navigationTitle("Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save changes logic would go here
                        isPresented = false
                    }
                }
            }
        }
    }
} 