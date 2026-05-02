import SwiftUI
import SwiftData

private enum AppTab { case journey, tools, progress }

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = AppTab.journey
    #if DEBUG
    @State private var showStrokeRecorder = false
    @State private var showStrokeReview = false
    #endif

    var body: some View {
        TabView(selection: $selectedTab) {
            JourneyView()
                .tabItem { Label("Journey", systemImage: "map.fill") }
                .tag(AppTab.journey)
            ToolsView()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver.fill") }
                .tag(AppTab.tools)
            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(AppTab.progress)
        }
        .tint(AppTheme.primaryColor)
        .onAppear {
            let progressRepository = ProgressRepository(modelContext: modelContext)
            _ = progressRepository.ensureUserProgress()
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if showsStrokeAdminMenu {
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
                        .foregroundStyle(.white)
                }
                .padding(.trailing, 16)
                .padding(.top, 4)
            }
        }
        .fullScreenCover(isPresented: $showStrokeRecorder) {
            StrokeRecorderView()
        }
        .fullScreenCover(isPresented: $showStrokeReview) {
            StrokeReviewView()
        }
        #endif
    }

    #if DEBUG
    private var showsStrokeAdminMenu: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-stroke-admin")
            || ProcessInfo.processInfo.environment["FIDEL_SHOW_STROKE_ADMIN"] == "1"
    }
    #endif
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
