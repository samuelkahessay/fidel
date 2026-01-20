import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressItems: [UserProgress]
    @State private var selectedTab = 0
    
    var userProgress: UserProgress {
        if let existing = progressItems.first {
            return existing
        }
        let newProgress = UserProgress()
        modelContext.insert(newProgress)
        return newProgress
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LearnView()
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }
                .tag(0)
            
            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "brain.head.profile")
                }
                .tag(1)
            
            ConversationsView()
                .tabItem {
                    Label("Conversations", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(2)
            
            ReferenceView()
                .tabItem {
                    Label("Reference", systemImage: "character.book.closed.fill")
                }
                .tag(3)
            
            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(4)
        }
        .tint(AppTheme.primaryColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProgress.self, FlashcardProgress.self], inMemory: true)
}
