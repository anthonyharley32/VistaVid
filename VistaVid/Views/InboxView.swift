import SwiftUI
import FirebaseAuth

struct InboxView: View {
    @State private var showNewMessageSheet = false
    @State private var messageModel = MessageViewModel()
    @State private var selectedUser: User?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messageModel.chatThreads) { thread in
                        // We'll implement this later when we have the user data
                        Button(action: {
                            // TODO: Fetch user and navigate
                        }) {
                            Text("Chat with @\(thread.participantIds.first ?? "")")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
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
                // New message sheet will go here
                Text("New Message")
                    .presentationDetents([.medium])
            }
        }
    }
}
