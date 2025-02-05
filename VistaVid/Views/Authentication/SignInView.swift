import SwiftUI
import FirebaseAuth

// MARK: - Properties
struct SignInView: View {
    @ObservedObject var model: AuthenticationViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Network Status Banner
                if model.isOffline {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("You're offline")
                        Text("•")
                        Text("Some features may be limited")
                    }
                    .font(.footnote)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.8))
                }
                
                // Logo and Welcome Text
                VStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 100)
                    
                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
                
                // Input Fields
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disabled(model.isLoading)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(model.isLoading)
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                // Sign In Button
                Button(action: signIn) {
                    HStack {
                        Spacer()
                        if model.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("AccentColor"))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(model.isLoading || (model.isOffline && !hasValidCredentials))
                .opacity((model.isOffline && !hasValidCredentials) ? 0.6 : 1.0)
                
                if model.isOffline && !hasValidCredentials {
                    Text("Sign in requires an internet connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Sign Up Link
                Button("Don't have an account? Sign Up") {
                    showSignUp = true
                }
                .foregroundColor(Color("AccentColor"))
                .padding(.top)
                .disabled(model.isLoading)
                
                Spacer()
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(model: model)
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var hasValidCredentials: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    // MARK: - Actions
    private func signIn() {
        // Debug log
        print("🔐 [SignIn]: Attempting to sign in with email: \(email)")
        
        Task {
            do {
                try await model.signIn(email: email, password: password)
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
                print("🔐 [SignIn]: Sign in failed with error: \(error.localizedDescription)")
            }
        }
    }
} 
