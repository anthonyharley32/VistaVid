import SwiftUI
import FirebaseAuth

struct ChatView: View {
    // MARK: - Properties
    let recipient: User
    @State private var messageText = ""
    @State private var messageModel = MessageViewModel()
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    @State private var threadId: String?
    
    // MARK: - Body
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(messageModel.messages.enumerated()), id: \.element.id) { index, message in
                        let thread = messageModel.chatThreads.first { thread in
                            thread.participantIds.contains(message.senderId) &&
                            thread.participantIds.contains(message.recipientId)
                        }
                        let user = thread?.participants?.first { $0.id == message.senderId }
                        
                        let isFirstInSequence = index == 0 || messageModel.messages[index - 1].senderId != message.senderId
                        
                        ChatMessageBubble(
                            message: message,
                            user: user,
                            isFromCurrentUser: message.senderId == Auth.auth().currentUser?.uid,
                            isFirstInSequence: isFirstInSequence
                        )
                    }
                }
                .padding(.vertical)
            }
            
            // Message input
            ChatInputField(
                messageText: $messageText,
                isLoading: isLoading,
                onSend: {
                    Task {
                        isLoading = true
                        do {
                            try await messageModel.sendMessage(messageText, to: recipient.id, in: threadId)
                            await MainActor.run {
                                messageText = ""
                            }
                        } catch {
                            print("❌ Error sending message: \(error.localizedDescription)")
                        }
                        isLoading = false
                    }
                }
            )
        }
        .navigationTitle("@\(recipient.username)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Find existing thread
            if let currentUserId = Auth.auth().currentUser?.uid {
                let snapshot = try? await FirestoreService.shared.db
                    .collection("chatThreads")
                    .whereField("participantIds", arrayContains: currentUserId)
                    .getDocuments()
                
                if let existingThread = snapshot?.documents.first(where: { document in
                    let data = document.data()
                    let participants = data["participantIds"] as? [String] ?? []
                    return participants.contains(recipient.id)
                }) {
                    threadId = existingThread.documentID
                    messageModel.startObservingMessages(in: existingThread.documentID)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatView(
            recipient: User(
                id: "preview",
                username: "johndoe",
                email: "john@example.com",
                createdAt: Date()
            )
        )
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(16)
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}
