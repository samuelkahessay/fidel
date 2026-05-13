import SwiftUI

struct ToolsView: View {
    @State private var selectedTool = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tool", selection: $selectedTool) {
                    Text("Selam AI").tag(0)
                    Text("Reference").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, AppTheme.Spacing.xs)
                .accessibilityLabel("Tool section")

                switch selectedTool {
                case 0:
                    SelamView(embedded: true)
                case 1:
                    ReferenceView(embedded: true)
                default:
                    EmptyView()
                }
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle(selectedTool == 0 ? "Selam AI" : "Reference")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ToolsView()
        .modelContainer(for: [
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ], inMemory: true)
}
