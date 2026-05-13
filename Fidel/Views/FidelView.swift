import SwiftData
import SwiftUI

struct FidelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCharacter: FidelCharacter?
    @State private var searchText = ""
    @State private var recognizedCharacterIds: Set<String> = []
    
    private let lessonRepository: LessonRepositoryProtocol = LessonRepository.shared
    let vowelHeaders = ["ä", "u", "i", "a", "e", "ə", "o"]
    
    var filteredChart: [[FidelCharacter]] {
        let chart = lessonRepository.getFidelChart()
        if searchText.isEmpty {
            return chart
        }
        return chart.map { row in
            row.filter { char in
                char.character.contains(searchText) ||
                char.romanization.lowercased().contains(searchText.lowercased())
            }
        }.filter { !$0.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                if filteredChart.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Characters Found",
                        message: "Try searching by an Ethiopic character or romanized sound."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geometry in
                        chartContent(width: geometry.size.width)
                    }
                }
            }
            .background(FidelPaperBackground())
            .navigationTitle("Fidel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search characters")
            .sheet(item: $selectedCharacter) { char in
                CharacterDetailView(character: char)
                    .presentationDetents([.medium])
            }
            .onAppear {
                refreshRecognition()
            }
        }
    }

    private func chartContent(width: CGFloat) -> some View {
        let metrics = FidelChartLayoutMetrics(containerWidth: width)

        return ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                vowelHeaderRow(metrics: metrics)

                ForEach(filteredChart.indices, id: \.self) { index in
                    let row = filteredChart[index]
                    if !row.isEmpty {
                        FidelRow(
                            characters: row,
                            metrics: metrics,
                            recognizedCharacterIds: recognizedCharacterIds,
                            selectedCharacter: $selectedCharacter
                        )
                    }
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
            .frame(width: width, alignment: .topLeading)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            FidelScreenHeader(
                title: "Fidel grid",
                amharicTitle: "ፊደል",
                subtitle: "Search, compare vowel forms, and open any character for sound cues."
            )

            HStack(spacing: AppTheme.Spacing.sm) {
                FidelChip(title: "34 rows", color: AppTheme.terracottaColor)
                FidelChip(title: "7 forms", color: AppTheme.goldColor)
                FidelChip(title: "\(recognizedCharacterIds.count) learned", color: AppTheme.eucalyptusColor)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
    
    private func vowelHeaderRow(metrics: FidelChartLayoutMetrics) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { index in
                Text(vowelHeaders[index])
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.terracottaDeepColor)
                    .frame(width: metrics.cellWidth, height: 24)
                    .accessibilityLabel("Vowel form \(vowelHeaders[index])")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func refreshRecognition() {
        let repository = ProgressRepository(modelContext: modelContext)
        let progress = repository.ensureUserProgress()
        recognizedCharacterIds = Set(progress.fidelCharactersRecognized)
    }
}

struct FidelChartLayoutMetrics {
    let containerWidth: CGFloat

    var horizontalPadding: CGFloat {
        min(AppTheme.Spacing.sm, max(AppTheme.Spacing.xxs, containerWidth * 0.015))
    }

    var cellWidth: CGFloat {
        floor(max(0, containerWidth - (horizontalPadding * 2)) / 7)
    }

    var cellHeight: CGFloat {
        min(52, max(44, cellWidth * 0.92))
    }

    var characterFontSize: CGFloat {
        min(28, max(22, cellWidth * 0.52))
    }

    var totalWidth: CGFloat {
        (horizontalPadding * 2) + (cellWidth * 7)
    }
}

struct FidelRow: View {
    let characters: [FidelCharacter]
    let metrics: FidelChartLayoutMetrics
    let recognizedCharacterIds: Set<String>
    @Binding var selectedCharacter: FidelCharacter?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            if let first = characters.first {
                Text(first.consonant)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Consonant row \(first.consonant)")
            }

            HStack(spacing: 0) {
                ForEach(characters) { char in
                    FidelCell(
                        character: char,
                        metrics: metrics,
                        isSelected: selectedCharacter?.id == char.id,
                        isRecognized: recognizedCharacterIds.contains(char.id)
                    ) {
                        withAnimation(AppTheme.Animation.quick) {
                            selectedCharacter = char
                        }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct FidelCell: View {
    let character: FidelCharacter
    let metrics: FidelChartLayoutMetrics
    let isSelected: Bool
    let isRecognized: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(character.character)
                    .font(AppTheme.Typography.amharicDisplay(size: metrics.characterFontSize, relativeTo: .title2))
                    .minimumScaleFactor(0.75)
                    .frame(width: metrics.cellWidth, height: metrics.cellHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cellBackground)
                    )
                    .foregroundStyle(isSelected ? AppTheme.onAccentColor : AppTheme.inkColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(cellStroke, lineWidth: 1)
                    )

                if isRecognized {
                    Circle()
                        .fill(isSelected ? AppTheme.onAccentColor : AppTheme.eucalyptusColor)
                        .frame(width: 7, height: 7)
                        .padding(5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(character.character), \(character.romanization)")
        .accessibilityHint("Shows pronunciation details")
        .accessibilityValue(isRecognized ? "Recognized" : (isSelected ? "Selected" : "Not yet recognized"))
    }

    private var cellBackground: Color {
        if isSelected { return AppTheme.terracottaColor }
        if isRecognized { return AppTheme.eucalyptusColor.opacity(0.12) }
        return AppTheme.cardColor
    }

    private var cellStroke: Color {
        if isSelected { return AppTheme.terracottaDeepColor.opacity(0.35) }
        if isRecognized { return AppTheme.eucalyptusColor.opacity(0.35) }
        return AppTheme.hairlineColor
    }
}

struct CharacterDetailView: View {
    let character: FidelCharacter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text(character.character)
                .font(AppTheme.Typography.amharicDisplay(size: 120, relativeTo: .largeTitle))
                .foregroundStyle(AppTheme.terracottaColor)
                .minimumScaleFactor(0.6)
            
            VStack(spacing: 8) {
                Text("Romanization")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                
                Text(character.romanization)
                    .font(.title)
                    .bold()
                    .foregroundStyle(AppTheme.inkColor)
            }
            
            HStack(spacing: 32) {
                VStack {
                    Text("Consonant")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    Text(character.consonant)
                        .font(.title2)
                        .foregroundStyle(AppTheme.inkColor)
                }
                
                VStack {
                    Text("Vowel Form")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondaryColor)
                    Text("\(character.vowelOrder)")
                        .font(.title2)
                        .foregroundStyle(AppTheme.inkColor)
                }
            }
            
            Text("Pronunciation: \(character.audioHint)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.terracottaColor.opacity(0.1))
                )
            
            Button(action: { dismiss() }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(32)
        .background(FidelPaperBackground())
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    FidelView()
}
