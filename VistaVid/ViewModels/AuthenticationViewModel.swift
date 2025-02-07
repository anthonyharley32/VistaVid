import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import FirebaseStorage
import Network

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case userNotFound
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case networkError
    case offlineError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message): return "Sign up failed: \(message)"
        case .signInFailed(let message): return "Sign in failed: \(message)"
        case .userNotFound: return "No user found with this email"
        case .invalidEmail: return "Please enter a valid email"
        case .weakPassword: return "Password must be at least 6 characters"
        case .emailAlreadyInUse: return "Email is already in use"
        case .networkError: return "Network connection error. Please check your internet connection"
        case .offlineError: return "You are currently offline. Some features may be limited"
        case .unknown: return "An unknown error occurred"
        }
    }
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    // MARK: - Properties
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var error: Error?
    @Published var isLoading = false
    @Published var isOffline = false
    
    // MARK: - Debug Properties
    private let debug = true // Set to false in production
    
    // MARK: - Initialization
    init() {
        setupAuthStateListener()
        setupNetworkMonitor()
    }
    
    private func setupFirestore() {
        // Remove Firestore configuration as it should only be done once at app startup
        debugLog("🔥 Firestore already configured")
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOffline = path.status != .satisfied
                self?.debugLog(self?.isOffline == true ? "Network connection lost" : "Network connection restored")
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Authentication Methods
    
    /// Signs up a new user with email and password
    func signUp(email: String, password: String, username: String) async throws {
        debugLog("🔐 Attempting to create new user")
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            debugLog("🔐 Successfully created user: \(result.user.uid)")
            
            let user = User(
                id: result.user.uid,
                username: username,
                email: email,
                createdAt: Date()
            )
            
            try await saveUserToFirestore(user)
            isAuthenticated = true
            currentUser = user
            
        } catch {
            debugLog("❌ Sign up error: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Signs in an existing user with email and password
    func signIn(email: String, password: String) async throws {
        debugLog("🔐 Attempting to sign in user")
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            debugLog("🔐 Successfully signed in user: \(result.user.uid)")
            isAuthenticated = true
            try await fetchUserData(userId: result.user.uid)
        } catch {
            debugLog("❌ Sign in error: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    /// Signs out the current user
    func signOut() throws {
        debugLog("🔐 Attempting to sign out user")
        do {
            try auth.signOut()
            debugLog("🔐 Successfully signed out user")
            isAuthenticated = false
            currentUser = nil
        } catch {
            debugLog("❌ Sign out error: \(error.localizedDescription)")
            self.error = error
            throw error
        }
    }
    
    // MARK: - Profile Management Methods
    
    /// Updates the user's profile picture
    func updateProfilePicture(_ image: UIImage) async throws {
        debugLog("📸 Attempting to update profile picture")
        guard let currentUser = currentUser else { 
            debugLog("❌ No current user found")
            throw AuthError.userNotFound 
        }
        
        do {
            // Convert image to data
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                debugLog("❌ Failed to convert image to JPEG data")
                throw AuthError.unknown
            }
            
            debugLog("📤 Starting upload to Firebase Storage")
            
            // Create a reference to Firebase Storage
            let storageRef = Storage.storage().reference()
            let profilePicRef = storageRef.child("profile_pictures/\(currentUser.id).jpg")
            
            // Upload the image
            debugLog("📤 Uploading image data: \(imageData.count) bytes")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await profilePicRef.putDataAsync(imageData, metadata: metadata)
            debugLog("✅ Image uploaded successfully")
            
            debugLog("🔗 Getting download URL...")
            let downloadURL = try await profilePicRef.downloadURL()
            debugLog("✅ Got download URL: \(downloadURL.absoluteString)")
            
            // Update Firestore with new profile picture URL
            debugLog("💾 Updating Firestore document...")
            let updateData: [String: Any] = ["profilePicUrl": downloadURL.absoluteString]
            try await db.collection("users").document(currentUser.id).updateData(updateData)
            
            // Update local user object
            debugLog("🔄 Updating local user object...")
            await MainActor.run {
                self.currentUser?.profilePicUrl = downloadURL.absoluteString
                debugLog("✅ Successfully updated profile picture")
            }
            
        } catch let storageError as StorageError {
            debugLog("❌ Storage error: \(storageError.localizedDescription)")
            throw AuthError.unknown
        } catch {
            debugLog("❌ Failed to update profile picture: \(error)")
            throw AuthError.unknown
        }
    }
    
    /// Updates the user's business account status
    func updateBusinessStatus(_ isBusiness: Bool) async throws {
        debugLog("Attempting to update business status to: \(isBusiness)")
        guard let currentUser = currentUser else { throw AuthError.userNotFound }
        
        do {
            let updateData: [String: Bool] = ["isBusiness": isBusiness]
            try await db.collection("users").document(currentUser.id).updateData(updateData)
            
            self.currentUser?.isBusiness = isBusiness
            debugLog("Successfully updated business status")
            
        } catch {
            debugLog("Failed to update business status: \(error.localizedDescription)")
            throw AuthError.unknown
        }
    }
    
    /// Updates the user's username
    func updateUsername(_ newUsername: String) async throws {
        debugLog("Attempting to update username to: \(newUsername)")
        guard let currentUser = currentUser else { throw AuthError.userNotFound }
        
        // Validate username
        guard !newUsername.isEmpty else {
            throw AuthError.signUpFailed("Username cannot be empty")
        }
        
        do {
            let updateData: [String: String] = ["username": newUsername]
            try await db.collection("users").document(currentUser.id).updateData(updateData)
            
            self.currentUser?.username = newUsername
            debugLog("Successfully updated username")
            
        } catch {
            debugLog("Failed to update username: \(error.localizedDescription)")
            throw AuthError.unknown
        }
    }
    
    /// Updates the user's algorithm preferences
    func updateAlgorithmPreferences(algorithm: String, isSelected: Bool) async throws {
        debugLog("Attempting to update algorithm preference: \(algorithm) to \(isSelected)")
        guard let currentUser = currentUser else { throw AuthError.userNotFound }
        
        var updatedAlgorithms = currentUser.selectedAlgorithms
        
        if isSelected && !updatedAlgorithms.contains(algorithm) {
            updatedAlgorithms.append(algorithm)
        } else if !isSelected {
            updatedAlgorithms.removeAll { $0 == algorithm }
        }
        
        do {
            let updateData: [String: [String]] = ["selectedAlgorithms": updatedAlgorithms]
            try await db.collection("users").document(currentUser.id).updateData(updateData)
            
            self.currentUser?.selectedAlgorithms = updatedAlgorithms
            debugLog("Successfully updated algorithm preferences")
            
        } catch {
            debugLog("Failed to update algorithm preferences: \(error.localizedDescription)")
            throw AuthError.unknown
        }
    }
    
    // MARK: - Helper Methods
    
    /// Sets up Firebase Auth state listener
    private func setupAuthStateListener() {
        debugLog("🔐 Setting up auth state listener")
        let _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.debugLog("🔐 User signed in: \(user.uid)")
                    self?.isAuthenticated = true
                    try? await self?.fetchUserData(userId: user.uid)
                } else {
                    self?.debugLog("🔐 User signed out")
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                }
            }
        }
    }
    
    /// Saves user data to Firestore
    private func saveUserToFirestore(_ user: User) async throws {
        debugLog("💾 Saving user to Firestore")
        do {
            try await db.collection("users").document(user.id).setData(user.toDictionary())
            debugLog("✅ Successfully saved user to Firestore")
        } catch {
            debugLog("❌ Error saving user: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches user data from Firestore
    private func fetchUserData(userId: String) async throws {
        debugLog("🔍 Fetching user data")
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                if let userData = document.data(),
                   let user = User.fromFirestore(userData, id: userId) {
                    debugLog("✅ Successfully fetched user data")
                    currentUser = user
                } else {
                    debugLog("❌ Failed to parse user data")
                    throw NSError(domain: "com.vistavid", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data"])
                }
            } else {
                debugLog("❌ No user document found")
                throw NSError(domain: "com.vistavid", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user found"])
            }
        } catch {
            debugLog("❌ Error fetching user: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Maps Firebase errors to our custom AuthError type
    private func mapFirebaseError(_ error: Error) -> AuthError {
        let authError = error as NSError
        
        // Check for network-related errors
        if authError.domain == NSURLErrorDomain {
            return .networkError
        }
        
        // Check for Firestore offline errors
        if authError.domain == FirestoreErrorDomain,
           authError.code == FirestoreErrorCode.unavailable.rawValue {
            return .offlineError
        }
        
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