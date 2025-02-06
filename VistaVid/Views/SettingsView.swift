import SwiftUI

struct SettingsView: View {
    let model: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            // Account Section
            Section("Account") {
                // Profile Settings
                NavigationLink {
                    ProfileEditView(model: model)
                } label: {
                    Label("Edit Profile", systemImage: "person.circle")
                }
                
                // Business Account Toggle
                BusinessAccountToggle(model: model, showingAlert: $showingAlert, alertMessage: $alertMessage)
            }
            
            // Content Rules Section
            Section {
                ContentRulesView(model: model)
            } header: {
                Text("Content Rules")
            } footer: {
                Text("Create custom rules to personalize your feed")
            }
            
            // Privacy & Safety
            Section("Privacy & Safety") {
                NavigationLink(destination: Text("Privacy Settings")) {
                    Label("Privacy", systemImage: "lock")
                }
                
                NavigationLink(destination: Text("Safety Settings")) {
                    Label("Safety", systemImage: "shield")
                }
            }
            
            // Support & About
            Section("Support & About") {
                Link(destination: URL(string: "https://vistavid.app/help")!) {
                    Label("Help Center", systemImage: "questionmark.circle")
                }
                
                Link(destination: URL(string: "https://vistavid.app/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                
                Link(destination: URL(string: "https://vistavid.app/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }
            
            // Sign Out
            Section {
                SignOutButton(model: model, showingAlert: $showingAlert, alertMessage: $alertMessage)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

// Profile Edit View
struct ProfileEditView: View {
    @ObservedObject var model: AuthenticationViewModel
    @State private var username: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section("Profile Information") {
                TextField("Username", text: $username)
            }
            
            Section {
                Button("Save Changes") {
                    Task {
                        do {
                            try await model.updateUsername(username)
                            dismiss()
                        } catch {
                            alertMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            username = model.currentUser?.username ?? ""
        }
    }
}
