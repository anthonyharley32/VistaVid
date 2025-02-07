import SwiftUI
import FirebaseAuth

struct InboxView: View {
    // MARK: - Properties
    @State private var showNewMessageSheet = false
    @State private var messageModel = MessageViewModel()
    @State private var selectedUser: User?
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messageModel.chatThreads) { thread in
                        NavigationLink(destination: {
                            if let otherUser = thread.participants?.first(where: { $0.id != Auth.auth().currentUser?.uid }) {
                                ChatView(recipient: otherUser)
                            }
                        }) {
                            ChatThreadRow(
                                thread: thread,
                                currentUserId: Auth.auth().currentUser?.uid ?? ""
                            )
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showNewMessageSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $showNewMessageSheet) {
                NavigationStack {
                    CommunitiesView(model: CommunitiesViewModel())
                        .navigationTitle("New Message")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showNewMessageSheet = false
                                }
                            }
                        }
                }
                .presentationDetents([.large])
            }
        }
    }
}

#Preview {
    InboxView()
}
