import SwiftUI
import FirebaseAuth

struct ChatView: View {
    let recipient: User
    @State private var messageText = ""
    @State private var messageModel = MessageViewModel()
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messageModel.messages) { message in
                        MessageBubble(message: message, isFromCurrentUser: message.senderId == Auth.auth().currentUser?.uid)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            // Message input
            HStack {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                
                Button(action: {
                    Task {
                        isLoading = true
                        do {
                            try await messageModel.sendMessage(messageText, to: recipient.id)
                            messageText = ""
                        } catch {
                            print("❌ Error sending message: \(error.localizedDescription)")
                        }
                        isLoading = false
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(messageText.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("@\(recipient.username)")
        .navigationBarTitleDisplayMode(.inline)
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
