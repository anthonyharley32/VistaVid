import SwiftUI
import FirebaseAuth

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
