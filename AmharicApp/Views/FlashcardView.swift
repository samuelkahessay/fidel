import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcardProgress: [FlashcardProgress]
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var offset: CGSize = .zero
    @State private var showCompletion = false
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    
    let vocabulary = AmharicData.vocabulary.shuffled().prefix(20)
    
    var currentWord: VocabularyWord? {
        currentIndex < vocabulary.count ? Array(vocabulary)[currentIndex] : nil
    }
    
    var body: some View {
        VStack(spacing: 24) {
            progressHeader
            
            if let word = currentWord, !showCompletion {
                flashcardStack(word: word)
                swipeHints
            } else if showCompletion {
                completionView
            }
        }
        .padding()
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var progressHeader: some View {
        HStack {
            Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Spacer()
            
            Text("\(currentIndex + 1)/\(vocabulary.count)")
                .font(.headline)
            
            Spacer()
            
            Label("\(incorrectCount)", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
        }
        .padding(.horizontal)
    }
    
    private func flashcardStack(word: VocabularyWord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 10, y: 5)
            
            VStack(spacing: 20) {
                if !isFlipped {
                    frontContent(word: word)
                } else {
                    backContent(word: word)
                }
            }
            .padding(32)
        }
        .frame(height: 350)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    handleSwipe(gesture: gesture)
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isFlipped.toggle()
            }
        }
        .overlay(
            swipeOverlay
        )
    }
    
    private func frontContent(word: VocabularyWord) -> some View {
        VStack(spacing: 16) {
            Text(word.amharic)
                .font(.system(size: 56))
                .foregroundColor(AppTheme.primaryColor)
            
            Text(word.transliteration)
                .font(.title3)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Tap to flip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func backContent(word: VocabularyWord) -> some View {
        VStack(spacing: 16) {
            Text(word.english)
                .font(.title)
                .fontWeight(.bold)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            
            Text(word.category)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppTheme.primaryColor.opacity(0.1))
                )
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            
            Spacer()
            
            Text("Swipe right if correct, left if not")
                .font(.caption)
                .foregroundColor(.secondary)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }
    
    private var swipeOverlay: some View {
        ZStack {
            if offset.width > 50 {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green, lineWidth: 4)
            } else if offset.width < -50 {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red, lineWidth: 4)
            }
        }
    }
    
    private var swipeHints: some View {
        HStack(spacing: 40) {
            VStack {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.red.opacity(0.5))
                Text("Still learning")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green.opacity(0.5))
                Text("Got it!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top)
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            AnimatedCheckmark()
            
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 32) {
                VStack {
                    Text("\(correctCount)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                    Text("Correct")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(incorrectCount)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.red)
                    Text("To Review")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            let percentage = vocabulary.count > 0 ? Int((Double(correctCount) / Double(vocabulary.count)) * 100) : 0
            Text("\(percentage)% Accuracy")
                .font(.headline)
                .foregroundColor(AppTheme.primaryColor)
            
            XPBadge(xp: correctCount * 5)
        }
        .padding()
    }
    
    private func handleSwipe(gesture: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if gesture.translation.width > threshold {
                offset = CGSize(width: 500, height: 0)
                correctCount += 1
                nextCard()
            } else if gesture.translation.width < -threshold {
                offset = CGSize(width: -500, height: 0)
                incorrectCount += 1
                nextCard()
            } else {
                offset = .zero
            }
        }
    }
    
    private func nextCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentIndex < vocabulary.count - 1 {
                currentIndex += 1
                offset = .zero
                isFlipped = false
            } else {
                showCompletion = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardView()
    }
    .modelContainer(for: [FlashcardProgress.self], inMemory: true)
}
