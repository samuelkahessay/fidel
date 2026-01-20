import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    let conversation: Conversation
    @Environment(\.modelContext) private var modelContext
    @Query private var progressItems: [UserProgress]
    
    @State private var currentLineIndex = 0
    @State private var isPlaying = false
    @State private var showTransliteration = true
    @State private var showEnglish = true
    @State private var practiceMode = false
    @State private var selectedRole: String?
    @State private var showCompletion = false
    
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
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
    }
    
    private var readingModeView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    difficultyBadge
                    
                    ForEach(Array(conversation.lines.enumerated()), id: \.element.id) { index, line in
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
                .fontWeight(.bold)
            
            Text("You'll practice speaking as this character")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
                .foregroundColor(.primary)
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
                        .foregroundColor(.secondary)
                    
                    Text(line.speaker)
                        .font(.headline)
                        .foregroundColor(isUserLine ? AppTheme.primaryColor : .secondary)
                    
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
                .foregroundColor(AppTheme.primaryColor)
            
            Text(line.amharic)
                .font(.system(size: 32))
                .foregroundColor(AppTheme.primaryColor)
                .multilineTextAlignment(.center)
            
            if showTransliteration {
                Text(line.transliteration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if showEnglish {
                Text(line.english)
                    .font(.body)
                    .foregroundColor(.blue)
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
                .foregroundColor(.secondary)
            
            Text(line.amharic)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
            
            if showTransliteration {
                Text(line.transliteration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if showEnglish {
                Text(line.english)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var difficultyBadge: some View {
        HStack {
            DifficultyStars(level: conversation.difficulty)
            
            Text(difficultyText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(conversation.lines.count) lines")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
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
            Button(action: { currentLineIndex = 0 }) {
                Image(systemName: "backward.end.fill")
            }
            .disabled(currentLineIndex == 0)
            
            Button(action: { if currentLineIndex > 0 { currentLineIndex -= 1 } }) {
                Image(systemName: "backward.fill")
            }
            .disabled(currentLineIndex == 0)
            
            Button(action: { togglePlayback() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            
            Button(action: { advanceLine() }) {
                Image(systemName: "forward.fill")
            }
            .disabled(currentLineIndex >= conversation.lines.count - 1)
            
            Button(action: { currentLineIndex = conversation.lines.count - 1 }) {
                Image(systemName: "forward.end.fill")
            }
            .disabled(currentLineIndex >= conversation.lines.count - 1)
        }
        .foregroundColor(AppTheme.primaryColor)
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.primary.opacity(0.1), radius: 10, y: -5)
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startAutoPlay()
        }
    }
    
    private func startAutoPlay() {
        guard isPlaying, currentLineIndex < conversation.lines.count - 1 else {
            isPlaying = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if isPlaying {
                advanceLine()
                startAutoPlay()
            }
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
        if let progress = progressItems.first {
            progress.practiceConversation(conversation.id)
        }
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
                .fontWeight(.bold)
                .foregroundColor(AppTheme.primaryColor)
            
            Text(line.amharic)
                .font(.system(size: 22))
            
            if showTransliteration {
                Text(line.transliteration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if showEnglish {
                Text(line.english)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? AppTheme.primaryColor.opacity(0.1) : Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? AppTheme.primaryColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(conversation: AmharicData.conversations[0])
    }
    .modelContainer(for: [UserProgress.self], inMemory: true)
}
