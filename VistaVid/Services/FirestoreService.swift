import FirebaseFirestore

// MARK: - Firestore Service
final class FirestoreService {
    // MARK: - Singleton
    static let shared = FirestoreService()
    
    // MARK: - Properties
    let db: Firestore
    
    // MARK: - Initializer
    private init() {
        self.db = Firestore.firestore()
    }
}
