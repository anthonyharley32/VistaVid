import SwiftUI
import FirebaseFirestore

struct CommunityDetailSheet: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @State private var creatorUser: User?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with large community icon
                    if community.iconType == "emoji" {
                        Text(community.iconEmoji ?? "👥")
                            .font(.system(size: 80))
                            .frame(width: 120, height: 120)
                            .background(Color(hex: community.backgroundColor ?? "#007AFF"))
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                    } else if let iconUrl = community.iconImageUrl {
                        AsyncImage(url: URL(string: iconUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                    
                    // Community Name
                    Text(community.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Stats Row
                    HStack(spacing: 30) {
                        VStack {
                            Text("\(community.membersCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Members")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            Text("\(community.followersCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Followers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(community.description)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Creator Info
                    if let creator = creatorUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Created by")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                if let profilePicUrl = creator.profilePicUrl {
                                    AsyncImage(url: URL(string: profilePicUrl)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(String(creator.username.prefix(1)).uppercased())
                                                .foregroundColor(.primary)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(creator.username)
                                        .fontWeight(.medium)
                                    Text(formatDate(community.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            await fetchCreator()
        }
    }
    
    private func fetchCreator() async {
        debugLog("Fetching creator with ID: \(community.creatorId)")
        do {
            let db = Firestore.firestore()
            let docRef = db.collection("users").document(community.creatorId)
            let document = try await docRef.getDocument()
            
            if let data = document.data(),
               let user = User.fromFirestore(data, id: document.documentID) {
                debugLog("Successfully fetched creator: \(user.username)")
                await MainActor.run {
                    self.creatorUser = user
                }
            }
        } catch {
            debugLog("Error fetching creator: \(error)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func debugLog(_ message: String) {
        print("CommunityDetailSheet Debug: \(message)")
    }
}