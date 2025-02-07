import SwiftUI
import FirebaseAuth

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: Message
    let user: User?
    let isFromCurrentUser: Bool
    let isFirstInSequence: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if !isFromCurrentUser {
                Group {
                    if isFirstInSequence {
                        CircularProfileImage(user: user ?? User.placeholder, size: 32)
                            .onAppear {
                                print("📱 [Chat]: Loading profile picture for user: \(user?.username ?? "unknown"), URL: \(user?.profilePicUrl ?? "nil")")
                            }
                    } else {
                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                }
                .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    if isFirstInSequence && !isFromCurrentUser && user != nil {
                        Text("@\(user?.username ?? "unknown")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    Text(message.content)
                        .padding(12)
                        .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                Group {
                    if isFirstInSequence {
                        CircularProfileImage(user: User.placeholder, size: 32)
                            .onAppear {
                                print("📱 [Chat]: Using placeholder profile picture for current user")
                            }
                    } else {
                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                }
                .frame(width: 32)
            }
        }
        .padding(.horizontal)
        .onAppear {
            print("📱 [Chat]: Message bubble appeared - From: \(isFromCurrentUser ? "current user" : user?.username ?? "unknown"), Content: \(message.content)")
        }
    }
}

// MARK: - Chat Input Field
struct ChatInputField: View {
    @Binding var messageText: String
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("Message...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
            
            Button(action: onSend) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
            }
            .disabled(messageText.isEmpty || isLoading)
        }
        .padding()
    }
}

// MARK: - Chat Thread Row
struct ChatThreadRow: View {
    let thread: ChatThread
    let currentUserId: String
    
    var otherParticipantId: String? {
        thread.participantIds.first { $0 != currentUserId }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            if let participant = thread.participants?.first(where: { $0.id != currentUserId }) {
                CircularProfileImage(user: participant, size: 50)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // Thread info
            VStack(alignment: .leading, spacing: 4) {
                if let participant = thread.participants?.first(where: { $0.id != currentUserId }) {
                    Text("@\(participant.username)")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Text("Loading...")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                if let lastMessage = thread.lastMessage {
                    Text(lastMessage.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Unread indicator
            if thread.unreadCount > 0 {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        ChatMessageBubble(
            message: Message(
                senderId: "sender1",
                recipientId: "recipient1",
                content: "Hello, how are you?"
            ),
            user: User(
                id: "user1",
                username: "johndoe",
                email: "john@example.com",
                createdAt: Date()
            ),
            isFromCurrentUser: false,
            isFirstInSequence: true
        )
        
        ChatMessageBubble(
            message: Message(
                senderId: "sender2",
                recipientId: "recipient2",
                content: "I'm doing great, thanks!"
            ),
            user: nil,
            isFromCurrentUser: true,
            isFirstInSequence: true
        )
        
        ChatInputField(
            messageText: .constant(""),
            isLoading: false,
            onSend: {}
        )
    }
    .padding()
} 