import SwiftUI
import FirebaseAuth

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
