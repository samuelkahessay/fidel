import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    let conversation: Conversation
    @Environment(\.modelContext) private var modelContext
    
    @State private var currentLineIndex = 0
    @State private var isPlaying = false
    @State private var showTransliteration = true
    @State private var showEnglish = true
    @State private var practiceMode = false
    @State private var selectedRole: String?
    @State private var showCompletion = false
    @State private var showCulturalNote = false
    @State private var autoPlayTask: Task<Void, Never>?

    private var culturalNotes: [CulturalNote] {
        LessonRepository.shared.getCulturalNotes(forConversation: conversation.id)
    }

    var speakers: [String] {
        Array(Set(conversation.lines.map { $0.speaker }))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if practiceMode {
                practiceModeView
            } else {
                readingModeView
            }
            
            controlsBar
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show Transliteration", isOn: $showTransliteration)
                    Toggle("Show English", isOn: $showEnglish)
                    Divider()
                    Button(action: { practiceMode.toggle() }) {
                        Label(practiceMode ? "Reading Mode" : "Practice Mode", 
                              systemImage: practiceMode ? "book" : "mic")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Conversation Complete!", isPresented: $showCompletion) {
            Button("Done") { }
        } message: {
            Text("You earned 20 XP for practicing this conversation!")
        }
        .onDisappear { autoPlayTask?.cancel() }
    }
    
    private var readingModeView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    difficultyBadge

                    if !culturalNotes.isEmpty {
                        culturalNoteBanner
                    }

                    ForEach(conversation.lines) { line in
                        let index = conversation.lines.firstIndex(where: { $0.id == line.id }) ?? 0
                        DialogueLineView(
                            line: line,
                            showTransliteration: showTransliteration,
                            showEnglish: showEnglish,
                            isHighlighted: index == currentLineIndex && isPlaying
                        )
                        .id(index)
                    }
                }
                .padding()
            }
            .onChange(of: currentLineIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    private var practiceModeView: some View {
        VStack(spacing: 20) {
            if selectedRole == nil {
                roleSelectionView
            } else {
                practiceDialogueView
            }
        }
        .padding()
    }
    
    private var roleSelectionView: some View {
        VStack(spacing: 20) {
            Text("Choose Your Role")
                .font(.title2)
                .bold()
            
            Text("You'll practice speaking as this character")
                .font(.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
            
            ForEach(speakers, id: \.self) { speaker in
                Button(action: { selectedRole = speaker }) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                        Text(speaker)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.primaryColor.opacity(0.1))
                    )
                }
                .foregroundStyle(AppTheme.inkColor)
            }
        }
    }
    
    private var practiceDialogueView: some View {
        VStack(spacing: 20) {
            if currentLineIndex < conversation.lines.count {
                let line = conversation.lines[currentLineIndex]
                let isUserLine = line.speaker == selectedRole
                
                VStack(spacing: 16) {
                    Text("Line \(currentLineIndex + 1) of \(conversation.lines.count)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    
                    Text(line.speaker)
                        .font(.headline)
                        .foregroundStyle(isUserLine ? AppTheme.primaryColor : .secondary)
                    
                    if isUserLine {
                        yourTurnView(line: line)
                    } else {
                        partnerLineView(line: line)
                    }
                }
                
                HStack(spacing: 20) {
                    if currentLineIndex > 0 {
                        Button(action: { currentLineIndex -= 1 }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Button(action: { advanceLine() }) {
                        Label("Next", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
    
    private func yourTurnView(line: Conversation.DialogueLine) -> some View {
        VStack(spacing: 16) {
            Text("Your turn! Say:")
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryColor)
            
            Text(line.amharic)
                .font(AppTheme.Typography.amharic(size: 32))
                .foregroundStyle(AppTheme.primaryColor)
                .multilineTextAlignment(.center)
            
            if showTransliteration {
                Text(line.transliteration)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            
            if showEnglish {
                Text(line.english)
                    .font(.body)
                    .foregroundStyle(AppTheme.infoColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.primaryColor.opacity(0.1))
        )
    }
    
    private func partnerLineView(line: Conversation.DialogueLine) -> some View {
        VStack(spacing: 12) {
            Text("Partner says:")
                .font(.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
            
            Text(line.amharic)
                .font(AppTheme.Typography.amharic(size: 24))
                .multilineTextAlignment(.center)
            
            if showTransliteration {
                Text(line.transliteration)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            
            if showEnglish {
                Text(line.english)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.infoColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.surfaceColor)
        )
    }
    
    private var difficultyBadge: some View {
        HStack {
            DifficultyStars(level: conversation.difficulty)
            
            Text(difficultyText)
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)
            
            Spacer()
            
            Text("\(conversation.lines.count) lines")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondaryColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surfaceColor)
        )
    }
    
    private var culturalNoteBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showCulturalNote.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: culturalNotes.first?.icon ?? "globe")
                        .font(.title3)
                        .foregroundStyle(AppTheme.secondaryColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cultural Context")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.secondaryColor)

                        Text(culturalNotes.first?.title ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.inkColor)
                    }

                    Spacer()

                    Image(systemName: showCulturalNote ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                }
            }
            .buttonStyle(.plain)

            if showCulturalNote {
                ForEach(culturalNotes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        if culturalNotes.count > 1 {
                            Text(note.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text(note.content)
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkSecondaryColor)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.secondaryColor.opacity(0.08))
        )
    }

    private var difficultyText: String {
        switch conversation.difficulty {
        case 1: return "Beginner"
        case 2: return "Intermediate"
        case 3: return "Advanced"
        default: return ""
        }
    }
    
    private var controlsBar: some View {
        HStack(spacing: 20) {
            Button("Jump to Start", systemImage: "backward.end.fill") { currentLineIndex = 0 }
                .labelStyle(.iconOnly)
                .disabled(currentLineIndex == 0)

            Button("Previous Line", systemImage: "backward.fill") { if currentLineIndex > 0 { currentLineIndex -= 1 } }
                .labelStyle(.iconOnly)
                .disabled(currentLineIndex == 0)

            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") { togglePlayback() }
                .labelStyle(.iconOnly)
                .font(.title)

            Button("Next Line", systemImage: "forward.fill") { advanceLine() }
                .labelStyle(.iconOnly)
                .disabled(currentLineIndex >= conversation.lines.count - 1)

            Button("Jump to End", systemImage: "forward.end.fill") { currentLineIndex = conversation.lines.count - 1 }
                .labelStyle(.iconOnly)
                .disabled(currentLineIndex >= conversation.lines.count - 1)
        }
        .foregroundStyle(AppTheme.primaryColor)
        .padding()
        .background(AppTheme.elevatedSurfaceColor)
        .shadow(color: AppTheme.Shadow.bottomBar, radius: 10, y: -5)
        .accessibilityElement(children: .contain)
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startAutoPlay()
        } else {
            autoPlayTask?.cancel()
        }
    }
    
    private func startAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = Task {
            while isPlaying, currentLineIndex < conversation.lines.count - 1 {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, isPlaying else { break }
                advanceLine()
            }
            isPlaying = false
        }
    }
    
    private func advanceLine() {
        if currentLineIndex < conversation.lines.count - 1 {
            currentLineIndex += 1
        } else {
            completeConversation()
        }
    }
    
    private func completeConversation() {
        let progressRepository = ProgressRepository(modelContext: modelContext)
        progressRepository.practiceConversation(conversation.id)
        showCompletion = true
    }
}

struct DialogueLineView: View {
    let line: Conversation.DialogueLine
    let showTransliteration: Bool
    let showEnglish: Bool
    let isHighlighted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(line.speaker)
                .font(.caption)
                .bold()
                .foregroundStyle(AppTheme.primaryColor)
            
            Text(line.amharic)
                .font(AppTheme.Typography.amharic(size: 22))
            
            if showTransliteration {
                Text(line.transliteration)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            
            if showEnglish {
                Text(line.english)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.infoColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? AppTheme.primaryColor.opacity(0.1) : AppTheme.cardColor)
                .shadow(color: AppTheme.Shadow.card, radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? AppTheme.primaryColor : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.speaker): \(line.amharic)")
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(conversation: AmharicData.conversations[0])
    }
    .modelContainer(for: [UserProgress.self], inMemory: true)
}
