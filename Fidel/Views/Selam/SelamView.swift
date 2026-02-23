import SwiftUI
import SwiftData

struct SelamView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SelamViewModel()
    @State private var scrollPosition: String?

    var embedded: Bool = false

    var body: some View {
        if embedded {
            selamContent
        } else {
            NavigationStack {
                selamContent
            }
        }
    }

    private var selamContent: some View {
        VStack(spacing: 0) {
            messagesView

            if !viewModel.suggestedActions.isEmpty && !viewModel.isLoading {
                SuggestedActionsView(
                    actions: viewModel.suggestedActions,
                    onSelect: viewModel.sendSuggestedAction
                )
            }

            ChatInputView(
                text: $viewModel.inputText,
                isLoading: viewModel.isLoading,
                onSend: { viewModel.sendMessage() },
                onCancel: { viewModel.cancelStreaming() }
            )
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Selam")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    SelamAvatarView(size: 28)
                    Text("Selam")
                        .font(AppTheme.Typography.headline)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { viewModel.startNewConversation() }) {
                        Label("New Conversation", systemImage: "plus.bubble")
                    }

                    Button(action: { viewModel.showHistory = true }) {
                        Label("Conversation History", systemImage: "clock.arrow.circlepath")
                    }

                    Divider()

                    Button(action: { viewModel.showSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .onAppear {
            configureViewModel()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SelamSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showHistory) {
            SelamHistoryView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Retry") { viewModel.retryLastMessage() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.error?.errorDescription ?? "An error occurred")
        }
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: viewModel.isLoading && message == viewModel.messages.last
                        )
                        .id(message.id.uuidString)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingContent) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id.uuidString, anchor: .bottom)
        }
    }
    
    private func configureViewModel() {
        let selamRepository = SelamRepository(modelContext: modelContext)
        let progressRepository = ProgressRepository(modelContext: modelContext)
        viewModel.configure(
            repository: selamRepository,
            progressRepository: progressRepository
        )
    }
}

struct SelamSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SelamViewModel
    
    @State private var coachingFrequency: SelamCoachingSettings.CoachingFrequency = .medium
    @State private var languagePreference: SelamCoachingSettings.LanguagePreference = .mixed
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Coaching") {
                    Picker("Frequency", selection: $coachingFrequency) {
                        ForEach(SelamCoachingSettings.CoachingFrequency.allCases, id: \.self) { freq in
                            VStack(alignment: .leading) {
                                Text(freq.rawValue)
                                Text(freq.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(freq)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section("Language") {
                    Picker("Response Language", selection: $languagePreference) {
                        ForEach(SelamCoachingSettings.LanguagePreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(languagePreference.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Snooze") {
                    Button("Snooze for 1 hour") {
                        viewModel.snoozeCoaching(for: 1)
                        dismiss()
                    }
                    
                    Button("Snooze for 24 hours") {
                        viewModel.snoozeCoaching(for: 24)
                        dismiss()
                    }
                }
                
                Section {
                    HStack {
                        Text("Messages today")
                        Spacer()
                        Text("\(viewModel.messageCountToday) / 100")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text("\(viewModel.remainingMessages)")
                            .foregroundColor(viewModel.remainingMessages < 10 ? .orange : .secondary)
                    }
                } header: {
                    Text("Usage")
                }
            }
            .navigationTitle("Selam Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                let settings = viewModel.coachingSettings
                coachingFrequency = settings.coachingFrequency
                languagePreference = settings.languagePreference
            }
        }
    }
    
    private func saveSettings() {
        let settings = SelamCoachingSettings(
            coachingFrequency: coachingFrequency,
            languagePreference: languagePreference,
            snoozedUntil: viewModel.coachingSettings.snoozedUntil
        )
        viewModel.updateCoachingSettings(settings)
    }
}

struct SelamHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let viewModel: SelamViewModel
    
    @Query(sort: \SelamConversation.updatedAt, order: .reverse)
    private var conversations: [SelamConversation]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conversation in
                    Button {
                        viewModel.loadConversation(conversation)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(conversation.title ?? "New Conversation")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(.primary)
                            
                            Text(conversation.preview)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.vertical, AppTheme.Spacing.xxs)
                    }
                }
                .onDelete(perform: deleteConversations)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .overlay {
                if conversations.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No Conversations",
                        message: "Start a conversation with Selam to see it here"
                    )
                }
            }
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(conversations[index])
        }
    }
}

struct SelamContextSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let entryContext: SelamEntryContext
    @State private var viewModel = SelamViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesView
                
                if !viewModel.suggestedActions.isEmpty && !viewModel.isLoading {
                    SuggestedActionsView(
                        actions: viewModel.suggestedActions,
                        onSelect: viewModel.sendSuggestedAction
                    )
                }
                
                ChatInputView(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    onSend: { viewModel.sendMessage() },
                    onCancel: { viewModel.cancelStreaming() }
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ask Selam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        SelamAvatarView(size: 28)
                        Text("Ask Selam")
                            .font(AppTheme.Typography.headline)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                configureViewModel()
            }
        }
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: viewModel.isLoading && message == viewModel.messages.last
                        )
                        .id(message.id.uuidString)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id.uuidString, anchor: .bottom)
        }
    }
    
    private func configureViewModel() {
        let selamRepository = SelamRepository(modelContext: modelContext)
        let progressRepository = ProgressRepository(modelContext: modelContext)
        viewModel.configure(
            repository: selamRepository,
            progressRepository: progressRepository,
            entryContext: entryContext
        )
    }
}

#Preview {
    SelamView()
        .modelContainer(for: [
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ], inMemory: true)
}
