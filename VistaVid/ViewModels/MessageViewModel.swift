import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable final class MessageViewModel {
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    private var threadsListener: ListenerRegistration?
    
    var messages: [Message] = []
    var chatThreads: [ChatThread] = []
    var isLoading = false
    var error: Error?
    
    // MARK: - Initialization
    init() {
        print("📱 MessageViewModel initialized")
        startObservingChatThreads()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    func startObservingChatThreads() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        threadsListener = db.collection("chatThreads")
            .whereField("participantIds", arrayContains: currentUserId)
            .order(by: "lastActivityAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error observing chat threads: \(error.localizedDescription)")
                    self?.error = error
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.chatThreads = documents.compactMap { document in
                    ChatThread.fromFirestore(document.data(), id: document.documentID)
                }
                print("✅ Successfully loaded \(self?.chatThreads.count ?? 0) chat threads")
            }
    }
    
    func startObservingMessages(in threadId: String) {
        messagesListener?.remove()
        
        messagesListener = db.collection("chatThreads")
            .document(threadId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error observing messages: \(error.localizedDescription)")
                    self?.error = error
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.messages = documents.compactMap { document in
                    Message.fromFirestore(document.data(), id: document.documentID)
                }
                print("✅ Successfully loaded \(self?.messages.count ?? 0) messages")
            }
    }
    
    func sendMessage(_ content: String, to recipientId: String, in threadId: String? = nil) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MessageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let actualThreadId: String
        if let existingThreadId = threadId {
            actualThreadId = existingThreadId
        } else {
            actualThreadId = try await findOrCreateThread(with: recipientId)
        }
        
        let message = Message(
            senderId: currentUserId,
            recipientId: recipientId,
            content: content
        )
        
        // Add message to thread
        try await db.collection("chatThreads")
            .document(actualThreadId)
            .collection("messages")
            .document(message.id)
            .setData(message.toDictionary())
        
        // Update thread metadata
        try await db.collection("chatThreads")
            .document(actualThreadId)
            .updateData([
                "lastMessage": message.toDictionary(),
                "lastActivityAt": Timestamp(date: Date()),
                "unreadCount": FieldValue.increment(Int64(1))
            ])
        
        print("✅ Successfully sent message to user: \(recipientId)")
    }
    
    func markThreadAsRead(_ threadId: String) async throws {
        try await db.collection("chatThreads")
            .document(threadId)
            .updateData([
                "unreadCount": 0
            ])
        print("✅ Marked thread as read: \(threadId)")
    }
    
    // MARK: - Private Methods
    private func findOrCreateThread(with recipientId: String) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { throw NSError(domain: "MessageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]) }
        
        // Check if thread exists
        let snapshot = try? await db.collection("chatThreads")
            .whereField("participantIds", arrayContains: currentUserId)
            .getDocuments()
        
        if let existingThread = snapshot?.documents.first(where: { document in
            let data = document.data()
            let participants = data["participantIds"] as? [String] ?? []
            return participants.contains(recipientId)
        }) {
            return existingThread.documentID
        }
        
        // Create new thread
        let thread = ChatThread(
            participantIds: [currentUserId, recipientId]
        )
        
        try? await db.collection("chatThreads")
            .document(thread.id)
            .setData(thread.toDictionary())
        
        return thread.id
    }
    
    func cleanup() {
        messagesListener?.remove()
        threadsListener?.remove()
    }
}
