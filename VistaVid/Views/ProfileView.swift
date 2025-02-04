import SwiftUI
import FirebaseAuth
import UIKit  // For UIImage type

struct ProfileView: View {
    // MARK: - Properties
    @ObservedObject var model: AuthenticationViewModel
    @State private var showingImagePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedImage: UIImage?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    HStack {
                        // Profile Image
                        if let profilePicUrl = model.currentUser?.profilePicUrl,
                           let url = URL(string: profilePicUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                        }
                        
                        // User Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.currentUser?.username ?? "Username")
                                .font(.headline)
                            Text(model.currentUser?.email ?? "Email")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading)
                    }
                    .padding(.vertical)
                    
                    Button("Change Profile Picture") {
                        showingImagePicker = true
                    }
                }
                
                // Account Settings
                Section("Account Settings") {
                    Toggle("Business Account", isOn: Binding(
                        get: { model.currentUser?.isBusiness ?? false },
                        set: { newValue in
                            Task {
                                // Update business status
                                try? await model.updateBusinessStatus(newValue)
                            }
                        }
                    ))
                }
                
                // Algorithm Preferences
                Section("Algorithm Preferences") {
                    ForEach(["AI", "Fitness", "Makeup", "Business"], id: \.self) { algorithm in
                        let isSelected = model.currentUser?.selectedAlgorithms.contains(algorithm) ?? false
                        Toggle(algorithm, isOn: Binding(
                            get: { isSelected },
                            set: { newValue in
                                Task {
                                    // Update algorithm preferences
                                    try? await model.updateAlgorithmPreferences(algorithm: algorithm, isSelected: newValue)
                                }
                            }
                        ))
                    }
                }
                
                // Sign Out Button
                Section {
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
            .navigationTitle("Profile")
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
                    .onChange(of: selectedImage) { oldValue, newValue in
                        if let image = newValue {
                            Task {
                                // Upload profile picture
                                try? await model.updateProfilePicture(image)
                            }
                        }
                    }
            }
        }
    }
} 