import SwiftUI

struct FidelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCharacter: FidelCharacter?
    @State private var searchText = ""
    
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
            .navigationTitle("Fidel Chart")
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
                            selectedCharacter: $selectedCharacter
                        )
                    }
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(width: width, alignment: .topLeading)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("ፊደል - Fidel")
                .font(.title2.bold())
            
            Text("The Ethiopic Script has 34 basic consonants, each with 7 vowel forms")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(AppTheme.primaryColor.opacity(0.1))
        .accessibilityElement(children: .combine)
    }
    
    private func vowelHeaderRow(metrics: FidelChartLayoutMetrics) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { index in
                Text(vowelHeaders[index])
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.primaryColor)
                    .frame(width: metrics.cellWidth, height: 24)
                    .accessibilityLabel("Vowel form \(vowelHeaders[index])")
            }
        }
        .accessibilityElement(children: .contain)
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
    @Binding var selectedCharacter: FidelCharacter?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            if let first = characters.first {
                Text(first.consonant)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Consonant row \(first.consonant)")
            }

            HStack(spacing: 0) {
                ForEach(characters) { char in
                    FidelCell(
                        character: char,
                        metrics: metrics,
                        isSelected: selectedCharacter?.id == char.id
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(character.character)
                .font(AppTheme.Typography.amharic(size: metrics.characterFontSize, relativeTo: .title2))
                .minimumScaleFactor(0.75)
                .frame(width: metrics.cellWidth, height: metrics.cellHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? AppTheme.primaryColor : Color.clear)
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.hairlineColor, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(character.character), \(character.romanization)")
        .accessibilityHint("Shows pronunciation details")
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

struct CharacterDetailView: View {
    let character: FidelCharacter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text(character.character)
                .font(AppTheme.Typography.amharic(size: 120))
                .foregroundStyle(AppTheme.primaryColor)
                .minimumScaleFactor(0.6)
            
            VStack(spacing: 8) {
                Text("Romanization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(character.romanization)
                    .font(.title)
                    .bold()
            }
            
            HStack(spacing: 32) {
                VStack {
                    Text("Consonant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(character.consonant)
                        .font(.title2)
                }
                
                VStack {
                    Text("Vowel Form")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(character.vowelOrder)")
                        .font(.title2)
                }
            }
            
            Text("Pronunciation: \(character.audioHint)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.primaryColor.opacity(0.1))
                )
            
            Button(action: { dismiss() }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(32)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    FidelView()
}
