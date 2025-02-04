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
                // Logo and Welcome Text
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to VistaVid")
                        .font(.title)
                        .fontWeight(.bold)
                    
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
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                // Sign In Button
                Button(action: signIn) {
                    if model.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
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
                
                // Sign Up Link
                Button("Don't have an account? Sign Up") {
                    showSignUp = true
                }
                .foregroundColor(.blue)
                .padding(.top)
                
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