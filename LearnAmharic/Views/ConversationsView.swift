import SwiftUI
import SwiftData

struct ConversationsView: View {
    @State private var viewModel = ConversationViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    
                    ForEach(viewModel.conversations) { conversation in
                        ConversationCard(conversation: conversation)
                            .onTapGesture {
                                viewModel.selectConversation(conversation)
                            }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Conversations")
            .navigationDestination(item: $viewModel.selectedConversation) { conversation in
                ConversationDetailView(conversation: conversation)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice Real Dialogues")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Master everyday conversations through interactive role-play. Practice both sides of the dialogue to build fluency.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.primaryColor.opacity(0.1))
        )
    }
}

struct ConversationCard: View {
    let conversation: Conversation
    @Query private var progressItems: [UserProgress]
    
    var isPracticed: Bool {
        progressItems.first?.conversationsPracticed.contains(conversation.id) ?? false
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isPracticed ? AppTheme.primaryColor : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if isPracticed {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.title3.bold())
                } else {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(AppTheme.primaryColor)
                        .font(.title3)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    DifficultyStars(level: conversation.difficulty)
                    
                    Text("\(conversation.lines.count) lines")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 4)
        )
    }
}

#Preview {
    ConversationsView()
        .modelContainer(for: [UserProgress.self], inMemory: true)
}
