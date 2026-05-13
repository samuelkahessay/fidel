import SwiftUI
import SwiftData

struct PronunciationPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var audioService = AudioService()
    @State private var currentIndex = 0
    @State private var isRecording = false
    @State private var hasRecorded = false
    @State private var showingComparison = false
    @State private var pronunciationMode: PronunciationMode = .phrases

    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared

    enum PronunciationMode: String, CaseIterable {
        case phrases = "Phrases"
        case vocabulary = "Vocabulary"
        case fidel = "Fidel"
    }
    
    var currentItems: [(amharic: String, transliteration: String, english: String)] {
        switch pronunciationMode {
        case .phrases:
            return lessonRepository.getPhrases().map { ($0.amharic, $0.transliteration, $0.english) }
        case .vocabulary:
            return lessonRepository.getVocabulary().map { ($0.amharic, $0.transliteration, $0.english) }
        case .fidel:
            var result: [(amharic: String, transliteration: String, english: String)] = []
            for row in lessonRepository.getFidelChart() {
                for char in row {
                    if result.count < 20 {
                        result.append((char.character, char.romanization, char.audioHint))
                    }
                }
            }
            return result
        }
    }
    
    var currentItem: (amharic: String, transliteration: String, english: String)? {
        guard currentIndex < currentItems.count else { return nil }
        return currentItems[currentIndex]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                
                if let item = currentItem {
                    ScrollView {
                        VStack(spacing: 32) {
                            progressIndicator
                            mainCard(item: item)
                            listenSection(item: item)
                            recordSection
                            if hasRecorded {
                                comparisonSection
                            }
                        }
                        .padding()
                    }
                } else {
                    completionView
                }
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle("Pronunciation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .fidelTabBarHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", systemImage: "forward.fill", action: skipToNext)
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
    
    private var modePicker: some View {
        Picker("Mode", selection: $pronunciationMode) {
            ForEach(PronunciationMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: pronunciationMode) { _, _ in
            currentIndex = 0
            hasRecorded = false
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) of \(currentItems.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(Double(currentIndex) / Double(currentItems.count) * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.primaryColor)
            }
            
            ProgressView(value: Double(currentIndex), total: Double(currentItems.count))
                .tint(AppTheme.primaryColor)
        }
    }
    
    private func mainCard(item: (amharic: String, transliteration: String, english: String)) -> some View {
        VStack(spacing: 16) {
            Text(item.amharic)
                .font(AppTheme.Typography.amharic(size: pronunciationMode == .fidel ? 72 : 36))
                .foregroundStyle(AppTheme.primaryColor)
                .multilineTextAlignment(.center)
            
            Text(item.transliteration)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Divider()
            
            Text(item.english)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Shadow.elevated, radius: 10, y: 5)
        )
    }
    
    private func listenSection(item: (amharic: String, transliteration: String, english: String)) -> some View {
        VStack(spacing: 12) {
            Text("Listen to Pronunciation")
                .font(.headline)
            
            HStack(spacing: 20) {
                Button(action: { audioService.speakAmharic(item.amharic) }) {
                    VStack(spacing: 8) {
                        Image(systemName: audioService.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                        Text("Play")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(AppTheme.primaryColor)
                    )
                }
                .disabled(audioService.isPlaying)
                .accessibilityLabel("Play native pronunciation")
                .accessibilityHint("Speaks \(item.amharic)")
                
                Button(action: { audioService.speakAmharic(item.amharic) }) {
                    VStack(spacing: 8) {
                        Image(systemName: "tortoise.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                        Text("Slow")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(AppTheme.warningColor)
                    )
                }
                .accessibilityLabel("Play slowly")
                .accessibilityHint("Speaks \(item.amharic) for slower practice")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Shadow.card, radius: 8, y: 4)
        )
    }
    
    private var recordSection: some View {
        VStack(spacing: 16) {
            Text(isRecording ? "Recording..." : "Your Turn")
                .font(.headline)
            
            Text(isRecording ? "Tap to stop" : "Tap to record your pronunciation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentRed)
                        .frame(width: 80, height: 80)
                    
                    if isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                    }
                }
            }
            .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
            .accessibilityHint(isRecording ? "Stops and saves your pronunciation recording" : "Records your pronunciation for comparison")
            .accessibilityValue(hasRecorded ? "Recording captured" : "No recording yet")
            
            if isRecording {
                HStack(spacing: 4) {
                    ForEach(Array(recordingBarHeights.enumerated()), id: \.offset) { _, height in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.accentRed)
                            .frame(width: 4, height: height)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.35).repeatForever(autoreverses: true),
                                value: isRecording
                            )
                    }
                }
                .frame(height: 40)
                .accessibilityLabel("Recording in progress")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Shadow.card, radius: 8, y: 4)
        )
    }
    
    private var comparisonSection: some View {
        VStack(spacing: 16) {
            Text("Compare Your Recording")
                .font(.headline)
            
            HStack(spacing: 32) {
                VStack(spacing: 8) {
                    Button(action: { 
                        if let item = currentItem {
                            audioService.speakAmharic(item.amharic)
                        }
                    }) {
                        Image(systemName: "person.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(AppTheme.primaryColor))
                    }
                    .accessibilityLabel("Play native pronunciation again")
                    Text("Native")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 8) {
                    Button(action: { audioService.playRecording() }) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(AppTheme.accentRed))
                    }
                    .accessibilityLabel("Play your recording")
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Button(action: { 
                    hasRecorded = false
                }) {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: moveToNext) {
                    Label("Next", systemImage: "arrow.right")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Shadow.card, radius: 8, y: 4)
        )
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.primaryColor)
            
            Text("Practice Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You practiced \(currentItems.count) items")
                .foregroundStyle(.secondary)
            
            Button("Practice Again") {
                currentIndex = 0
                hasRecorded = false
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
    
    private func toggleRecording() {
        if isRecording {
            _ = audioService.stopRecording()
            isRecording = false
            hasRecorded = true
        } else {
            audioService.startRecording()
            isRecording = true
        }
    }

    private var recordingBarHeights: [CGFloat] {
        reduceMotion ? [18, 18, 18, 18, 18] : [12, 26, 18, 32, 22]
    }
    
    private func moveToNext() {
        if currentIndex < currentItems.count - 1 {
            currentIndex += 1
            hasRecorded = false
        }
    }
    
    private func skipToNext() {
        moveToNext()
    }
}

#Preview {
    PronunciationPracticeView()
}
