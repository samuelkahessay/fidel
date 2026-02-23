import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    #if DEBUG
    @State private var showStrokeRecorder = false
    @State private var showStrokeReview = false
    #endif

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
        .onAppear {
            let progressRepository = ProgressRepository(modelContext: modelContext)
            _ = progressRepository.ensureUserProgress()
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Menu {
                Button {
                    showStrokeRecorder = true
                } label: {
                    Label("Record Strokes", systemImage: "pencil.tip.crop.circle")
                }
                Button {
                    showStrokeReview = true
                } label: {
                    Label("Review Strokes", systemImage: "hand.thumbsup.fill")
                }
            } label: {
                Label("Strokes", systemImage: "pencil.tip.crop.circle")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.indigo, in: Capsule())
                    .foregroundColor(.white)
            }
            .padding(.trailing, 16)
            .padding(.top, 4)
        }
        .fullScreenCover(isPresented: $showStrokeRecorder) {
            StrokeRecorderView()
        }
        .fullScreenCover(isPresented: $showStrokeReview) {
            StrokeReviewView()
        }
        #endif
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
