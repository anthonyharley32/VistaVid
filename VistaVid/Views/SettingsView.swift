import SwiftUI

struct SettingsView: View {
    let model: AuthenticationViewModel
    let settingsModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        List {
            // Profile Section
            Section {
                // User Profile Header
                if let user = model.currentUser {
                    HStack(spacing: 15) {
                        // Profile Picture
                        AsyncImage(url: URL(string: user.profilePicUrl ?? "")) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            case .failure:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(Image(systemName: "person.fill")
                                        .foregroundColor(.gray))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                        // User Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.username)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Edit Profile Button
                NavigationLink {
                    ProfileEditView(model: model)
                } label: {
                    Label("Edit Profile", systemImage: "pencil.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            // Content & Personalization
            Section {
                ContentRulesView(model: model)
            } header: {
                Label("Content & Personalization", systemImage: "slider.horizontal.3")
                    .textCase(nil)
                    .foregroundColor(.primary)
                    .font(.headline)
            } footer: {
                Text("Customize your feed with personalized content rules")
            }
            
            // Privacy & Safety
            Section {
                NavigationLink(destination: PrivacySettingsView()) {
                    Label("Privacy Settings", systemImage: "lock.fill")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: SafetySettingsView()) {
                    Label("Safety Settings", systemImage: "shield.fill")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: NotificationSettingsView()) {
                    Label("Notifications", systemImage: "bell.fill")
                        .foregroundColor(.primary)
                }
            } header: {
                Label("Privacy & Safety", systemImage: "hand.raised.fill")
                    .textCase(nil)
                    .foregroundColor(.primary)
                    .font(.headline)
            }
            
            // Accessibility Settings
            Section {
                Toggle(isOn: .init(
                    get: { settingsModel.isHandsFreeEnabled },
                    set: { settingsModel.isHandsFreeEnabled = $0 }
                )) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Hands-Free Mode")
                            Text("Control videos using eye gestures")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "eye")
                    }
                }
            } header: {
                Label("Accessibility", systemImage: "accessibility")
                    .textCase(nil)
                    .foregroundColor(.primary)
                    .font(.headline)
            } footer: {
                Text("Left wink: previous video\nBoth eyes blink: play/pause\nRight wink: next video")
            }
            
            // Support & Legal
            Section {
                Link(destination: URL(string: "https://vistavid.app/help")!) {
                    HStack {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://vistavid.app/terms")!) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://vistavid.app/privacy")!) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Support & Legal", systemImage: "info.circle.fill")
                    .textCase(nil)
                    .foregroundColor(.primary)
                    .font(.headline)
            }
            
            // Sign Out
            Section {
                Button(role: .destructive) {
                    showingSignOutConfirmation = true
                } label: {
                    HStack {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Are you sure you want to sign out?",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    do {
                        try model.signOut()
                    } catch {
                        alertMessage = error.localizedDescription
                        showingAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// Profile Edit View
struct ProfileEditView: View {
    @ObservedObject var model: AuthenticationViewModel
    @State private var username: String = ""
    @State private var showingImagePicker = false
    @State private var profileImage: UIImage?
    @State private var isUpdatingProfile = false
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            Section {
                // Profile Picture
                HStack {
                    Spacer()
                    Button(action: { showingImagePicker = true }) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        } else if let url = model.currentUser?.profilePicUrl,
                                  let imageUrl = URL(string: url) {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 100, height: 100)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                case .failure:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 10)
                
                // Username Field
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
            } header: {
                Text("Profile Information")
            } footer: {
                Text("This information will be visible to other users")
            }
            
            Section {
                Button(action: saveChanges) {
                    HStack {
                        Text("Save Changes")
                        Spacer()
                        if isUpdatingProfile {
                            ProgressView()
                        }
                    }
                }
                .disabled(isUpdatingProfile)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $profileImage)
        }
        .onAppear {
            username = model.currentUser?.username ?? ""
        }
    }
    
    private func saveChanges() {
        isUpdatingProfile = true
        Task {
            do {
                if let image = profileImage {
                    try await model.updateProfilePicture(image)
                }
                try await model.updateUsername(username)
                await MainActor.run {
                    isUpdatingProfile = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdatingProfile = false
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

// Placeholder Views
struct PrivacySettingsView: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

struct SafetySettingsView: View {
    var body: some View {
        Text("Safety Settings")
            .navigationTitle("Safety")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        Text("Notification Settings")
            .navigationTitle("Notifications")
    }
}
