import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case userNotFound
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message): return "Sign up failed: \(message)"
        case .signInFailed(let message): return "Sign in failed: \(message)"
        case .userNotFound: return "No user found with this email"
        case .invalidEmail: return "Please enter a valid email"
        case .weakPassword: return "Password must be at least 6 characters"
        case .emailAlreadyInUse: return "Email is already in use"
        case .unknown: return "An unknown error occurred"
        }
    }
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    // MARK: - Properties
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    // MARK: - Debug Properties
    private let debug = true // Set to false in production
    
    // MARK: - Initialization
    init() {
        // Debug log for initialization
        debugLog("AuthenticationViewModel initialized")
        setupAuthStateListener()
    }
    
    // MARK: - Authentication Methods
    
    /// Signs up a new user with email and password
    func signUp(email: String, password: String, username: String) async throws {
        debugLog("Attempting to sign up user with email: \(email)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create user in Firebase Auth
            let authResult = try await auth.createUser(withEmail: email, password: password)
            
            // Create user model
            let user = User.fromFirebaseUser(authResult.user, username: username)
            
            // Save user data to Firestore
            try await saveUserToFirestore(user)
            
            currentUser = user
            isAuthenticated = true
            debugLog("Successfully signed up user: \(user.id)")
            
        } catch {
            debugLog("Sign up failed with error: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    /// Signs in an existing user with email and password
    func signIn(email: String, password: String) async throws {
        debugLog("Attempting to sign in user with email: \(email)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            try await fetchUserData(userId: authResult.user.uid)
            debugLog("Successfully signed in user: \(authResult.user.uid)")
            
        } catch {
            debugLog("Sign in failed with error: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    /// Signs out the current user
    func signOut() throws {
        debugLog("Attempting to sign out user")
        do {
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
            debugLog("Successfully signed out user")
        } catch {
            debugLog("Sign out failed with error: \(error.localizedDescription)")
            throw AuthError.unknown
        }
    }
    
    // MARK: - Helper Methods
    
    /// Sets up Firebase Auth state listener
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            Task {
                if let user = user {
                    self.debugLog("Auth state changed: User logged in with ID: \(user.uid)")
                    try? await self.fetchUserData(userId: user.uid)
                } else {
                    self.debugLog("Auth state changed: User logged out")
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    /// Saves user data to Firestore
    private func saveUserToFirestore(_ user: User) async throws {
        debugLog("Saving user data to Firestore for user: \(user.id)")
        try await db.collection("users").document(user.id).setData(user.toDictionary())
    }
    
    /// Fetches user data from Firestore
    private func fetchUserData(userId: String) async throws {
        debugLog("Fetching user data for user: \(userId)")
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data() else {
            debugLog("No user data found in Firestore")
            throw AuthError.userNotFound
        }
        
        // Map Firestore data to User model
        currentUser = User(
            id: userId,
            username: data["username"] as? String ?? "",
            email: data["email"] as? String ?? "",
            profilePicUrl: data["profilePicUrl"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            isBusiness: data["isBusiness"] as? Bool ?? false,
            selectedAlgorithms: data["selectedAlgorithms"] as? [String] ?? []
        )
        isAuthenticated = true
        debugLog("Successfully fetched user data")
    }
    
    /// Maps Firebase errors to our custom AuthError type
    private func mapFirebaseError(_ error: Error) -> AuthError {
        let authError = error as NSError
        switch authError.code {
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        default:
            return .unknown
        }
    }
    
    /// Debug logging function
    private func debugLog(_ message: String) {
        if debug {
            print("🔐 [Auth]: \(message)")
        }
    }
} 