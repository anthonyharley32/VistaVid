import SwiftUI
import FirebaseAuth

// MARK: - Content Rule Model
struct ContentRule: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var isActive: Bool
    var emoji: String
}

// MARK: - Content Rules View
struct ContentRulesView: View {
    @ObservedObject var model: AuthenticationViewModel
    // Debug: Track rules state changes
    @State private var rules: [ContentRule] = [
        ContentRule(
            title: "AI Learning",
            description: "Teach me about AI and the newest tools like ML Core, Cursor tips, and other productivity tools",
            isActive: true,
            emoji: "🤖"
        ),
        ContentRule(
            title: "Workout Mode",
            description: "Show me HIIT workouts and strength training content between 5-15 minutes",
            isActive: false,
            emoji: "💪"
        )
    ]
    @State private var showingAddRule = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable rules list
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    ForEach(rules) { rule in
                        ContentRuleCard(rule: rule)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Add Rule Button - Pinned at bottom
            VStack {
                Button(action: { showingAddRule = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add New Rule")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemBackground))
        }
        .sheet(isPresented: $showingAddRule) {
            AddRuleView(isPresented: $showingAddRule)
        }
    }
}

// MARK: - Content Rule Card View
struct ContentRuleCard: View {
    let rule: ContentRule
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rule.emoji)
                    .font(.title2)
                Text(rule.title)
                    .font(.headline)
                Spacer()
                Toggle("", isOn: .constant(rule.isActive))
                    .labelsHidden()
            }
            
            Text(rule.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Button(action: { isEditing = true }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                Spacer()
                Button(action: { /* Delete action */ }) {
                    Label("Delete", systemImage: "trash")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $isEditing) {
            EditRuleView(rule: rule, isPresented: $isEditing)
        }
    }
}

// MARK: - Add Rule View
struct AddRuleView: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var selectedEmoji = "📱"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    // Emoji Picker (simplified)
                    Picker("Icon", selection: $selectedEmoji) {
                        ForEach(["📱", "🤖", "💪", "🎨", "📚", "🎮", "🎵"], id: \.self) { emoji in
                            Text(emoji)
                        }
                    }
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Add rule logic would go here
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Edit Rule View
struct EditRuleView: View {
    let rule: ContentRule
    @Binding var isPresented: Bool
    @State private var title: String
    @State private var description: String
    @State private var selectedEmoji: String
    
    init(rule: ContentRule, isPresented: Binding<Bool>) {
        self.rule = rule
        self._isPresented = isPresented
        self._title = State(initialValue: rule.title)
        self._description = State(initialValue: rule.description)
        self._selectedEmoji = State(initialValue: rule.emoji)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Details") {
                    TextField("Rule Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    // Emoji Picker (simplified)
                    Picker("Icon", selection: $selectedEmoji) {
                        ForEach(["📱", "🤖", "💪", "🎨", "📚", "🎮", "🎵"], id: \.self) { emoji in
                            Text(emoji)
                        }
                    }
                }
            }
            .navigationTitle("Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save changes logic would go here
                        isPresented = false
                    }
                }
            }
        }
    }
}
