import SwiftUI
import SwiftData

private enum AppTab: String {
    case journey, tools, progress

    var title: String {
        switch self {
        case .journey: return "Journey"
        case .tools: return "Tools"
        case .progress: return "Progress"
        }
    }

    var icon: String {
        switch self {
        case .journey: return "map"
        case .tools: return "wrench.and.screwdriver"
        case .progress: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .journey: return "map.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .progress: return "chart.bar.fill"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = AppTab.journey
    @State private var hidesTabBar = false
    #if DEBUG
    @State private var showStrokeRecorder = false
    @State private var showStrokeReview = false
    #endif

    var body: some View {
        VStack(spacing: 0) {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Group {
                if !hidesTabBar {
                    RootTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, AppTheme.Spacing.sm)
                        .padding(.bottom, AppTheme.Spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .tint(AppTheme.primaryColor)
        .animation(AppTheme.Animation.gentle, value: hidesTabBar)
        .onPreferenceChange(FidelTabBarHiddenPreferenceKey.self) { hidesTabBar = $0 }
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
                        .background(AppTheme.practiceColor, in: Capsule())
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

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .journey:
            JourneyView()
        case .tools:
            ToolsView()
        case .progress:
            ProgressDashboardView()
        }
    }

    #if DEBUG
    private var showsStrokeAdminMenu: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-stroke-admin")
            || ProcessInfo.processInfo.environment["FIDEL_SHOW_STROKE_ADMIN"] == "1"
    }
    #endif
}

private struct RootTabBar: View {
    @Binding var selectedTab: AppTab

    private let tabs: [AppTab] = [.journey, .tools, .progress]

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(AppTheme.Spacing.xs)
        .fidelSurface(.glass, cornerRadius: 28)
        .shadow(
            color: AppTheme.Shadow.elevated,
            radius: 18,
            x: 0,
            y: 8
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, height: 22)

                Text(tab.title)
                    .font(AppTheme.Typography.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isSelected ? AppTheme.primaryColor : AppTheme.subtleTextColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, AppTheme.Spacing.xs)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.primaryColor.opacity(0.14))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.title) tab")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Switches to the \(tab.title) section")
        .accessibilityIdentifier("tab.\(tab.rawValue)")
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
