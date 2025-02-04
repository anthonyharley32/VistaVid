import SwiftUI

struct SignUpView: View {
    // MARK: - Properties
    let model: AuthenticationViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Join VistaVid today")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 50)
            
            // Input Fields
            VStack(spacing: 15) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.top, 30)
            
            // Sign Up Button
            Button(action: signUp) {
                if model.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(model.isLoading)
            
            // Sign In Link
            Button("Already have an account? Sign In") {
                dismiss()
            }
            .foregroundColor(.blue)
            .padding(.top)
            
            Spacer()
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Actions
    private func signUp() {
        // Validate input
        guard !username.isEmpty else {
            alertMessage = "Please enter a username"
            showAlert = true
            return
        }
        
        // Debug log
        print("🔐 [SignUp]: Attempting to sign up with email: \(email)")
        
        Task {
            do {
                try await model.signUp(email: email, password: password, username: username)
                dismiss() // Dismiss the sign up view on success
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
                print("🔐 [SignUp]: Sign up failed with error: \(error.localizedDescription)")
            }
        }
    }
} 