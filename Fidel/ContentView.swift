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
            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "map.fill")
                }
                .tag(0)

            ToolsView()
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(1)

            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(2)
        }
        .tint(AppTheme.primaryColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ], inMemory: true)
}
