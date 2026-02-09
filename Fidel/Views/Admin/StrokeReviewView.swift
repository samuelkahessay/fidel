import SwiftUI

/// Tinder-style card swipe screen for reviewing all 238 character stroke recordings.
/// Swipe right (or tap checkmark) to approve, swipe left (or tap X) to flag as bad.
/// Debug-only admin tool.
struct StrokeReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var characters: [FidelCharacter] = []
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var flaggedIds: Set<String> = []
    @State private var reviewedIds: Set<String> = []
    @State private var history: [ReviewAction] = []
    @State private var isFinished = false

    private let swipeThreshold: CGFloat = 100

    private enum ReviewAction {
        case approved(Int)  // index
        case flagged(Int)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if characters.isEmpty {
                    ProgressView("Loading...")
                } else if isFinished {
                    summaryView
                } else {
                    cardSwipeView
                }
            }
            .navigationTitle("Stroke Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !isFinished {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            undoLast()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(history.isEmpty)
                    }
                }
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Card Swipe View

    private var cardSwipeView: some View {
        let character = characters[currentIndex]
        let hasStroke = StrokeDataRepository.shared.hasStrokeData(for: character.id)

        return VStack(spacing: 20) {
            // Progress counter
            Text("\(reviewedIds.count + 1) / \(characters.count)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            // Card
            ZStack {
                // Approval / rejection overlay tints
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.green.opacity(greenOverlayOpacity))
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                            .opacity(greenOverlayOpacity * 2)
                    )

                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.red.opacity(redOverlayOpacity))
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)
                            .opacity(redOverlayOpacity * 2)
                    )

                // Card content
                VStack(spacing: 16) {
                    if hasStroke {
                        StrokeAnimationView(
                            character: character.character,
                            size: CGSize(width: 180, height: 180),
                            characterId: character.id
                        )
                        .id("review-\(character.id)-\(currentIndex)")
                    } else {
                        Text(character.character)
                            .font(.system(size: 120))
                            .frame(width: 180, height: 180)
                        Text("No stroke data")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text(character.character)
                        .font(.system(size: 44, weight: .bold))

                    Text(character.romanization)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if hasStroke, let data = StrokeDataRepository.shared.getStrokeData(for: character.id) {
                        Text("\(data.strokes.count) stroke\(data.strokes.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(32)
            }
            .frame(width: 300, height: 420)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(radius: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        handleSwipeEnd(translation: value.translation)
                    }
            )

            Spacer()

            // Action buttons
            HStack(spacing: 60) {
                Button {
                    animateSwipe(direction: .left)
                } label: {
                    Image(systemName: "xmark")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.red, in: Circle())
                }

                Button {
                    animateSwipe(direction: .right)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.green, in: Circle())
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Summary View

    private var summaryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Review Complete")
                .font(.largeTitle.bold())

            VStack(spacing: 8) {
                Text("\(reviewedIds.count) reviewed")
                    .font(.title3)
                Text("\(flaggedIds.count) flagged")
                    .font(.title3)
                    .foregroundColor(flaggedIds.isEmpty ? .secondary : .red)
            }

            if !flaggedIds.isEmpty {
                flaggedListView
            }

            Button("Review Again") {
                resetReview()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var flaggedListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flagged Characters")
                .font(.headline)
                .padding(.top, 8)

            let flaggedChars = characters.filter { flaggedIds.contains($0.id) }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(50)), count: 6), spacing: 8) {
                    ForEach(flaggedChars, id: \.id) { char in
                        VStack(spacing: 2) {
                            Text(char.character)
                                .font(.title2)
                            Text(char.romanization)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 50, height: 50)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 250)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Overlay Opacity

    private var greenOverlayOpacity: CGFloat {
        guard offset.width > 0 else { return 0 }
        return min(offset.width / swipeThreshold, 1) * 0.3
    }

    private var redOverlayOpacity: CGFloat {
        guard offset.width < 0 else { return 0 }
        return min(-offset.width / swipeThreshold, 1) * 0.3
    }

    // MARK: - Swipe Handling

    private enum SwipeDirection { case left, right }

    private func handleSwipeEnd(translation: CGSize) {
        if translation.width > swipeThreshold {
            commitSwipe(direction: .right)
        } else if translation.width < -swipeThreshold {
            commitSwipe(direction: .left)
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = .zero
            }
        }
    }

    private func animateSwipe(direction: SwipeDirection) {
        let targetX: CGFloat = direction == .right ? 500 : -500
        withAnimation(.easeIn(duration: 0.2)) {
            offset = CGSize(width: targetX, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            commitAction(direction: direction)
        }
    }

    private func commitSwipe(direction: SwipeDirection) {
        let targetX: CGFloat = direction == .right ? 500 : -500
        withAnimation(.easeIn(duration: 0.15)) {
            offset = CGSize(width: targetX, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            commitAction(direction: direction)
        }
    }

    private func commitAction(direction: SwipeDirection) {
        let id = characters[currentIndex].id

        switch direction {
        case .right:
            reviewedIds.insert(id)
            flaggedIds.remove(id)
            history.append(.approved(currentIndex))
        case .left:
            reviewedIds.insert(id)
            flaggedIds.insert(id)
            history.append(.flagged(currentIndex))
        }

        saveState()
        offset = .zero

        if currentIndex + 1 < characters.count {
            currentIndex += 1
            advanceToNextUnreviewed()
        } else {
            isFinished = true
        }
    }

    // MARK: - Undo

    private func undoLast() {
        guard let last = history.popLast() else { return }
        let prevIndex: Int
        switch last {
        case .approved(let idx):
            reviewedIds.remove(characters[idx].id)
            prevIndex = idx
        case .flagged(let idx):
            let id = characters[idx].id
            reviewedIds.remove(id)
            flaggedIds.remove(id)
            prevIndex = idx
        }
        isFinished = false
        currentIndex = prevIndex
        offset = .zero
        saveState()
    }

    // MARK: - Navigation

    private func advanceToNextUnreviewed() {
        // If current card is already reviewed (undo/resume scenario), skip to next unreviewed
        while currentIndex < characters.count && reviewedIds.contains(characters[currentIndex].id) {
            currentIndex += 1
        }
        if currentIndex >= characters.count {
            isFinished = true
        }
    }

    // MARK: - Persistence

    private static let flaggedKey = "flaggedStrokeIds"
    private static let reviewedKey = "reviewedStrokeIds"

    private func loadData() {
        characters = AmharicData.fidelChart.flatMap { $0 }

        if let saved = UserDefaults.standard.array(forKey: Self.flaggedKey) as? [String] {
            flaggedIds = Set(saved)
        }
        if let saved = UserDefaults.standard.array(forKey: Self.reviewedKey) as? [String] {
            reviewedIds = Set(saved)
        }

        // Resume: jump to first unreviewed character
        if !reviewedIds.isEmpty {
            advanceToNextUnreviewed()
        }

        if let forcedId = debugValue(for: "-stroke-review-character-id"),
           let forcedIndex = characters.firstIndex(where: { $0.id == forcedId }) {
            currentIndex = forcedIndex
            isFinished = false
        }
    }

    private func saveState() {
        UserDefaults.standard.set(Array(flaggedIds), forKey: Self.flaggedKey)
        UserDefaults.standard.set(Array(reviewedIds), forKey: Self.reviewedKey)
    }

    private func resetReview() {
        reviewedIds.removeAll()
        flaggedIds.removeAll()
        history.removeAll()
        currentIndex = 0
        isFinished = false
        saveState()
    }

    private func debugValue(for flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

}
