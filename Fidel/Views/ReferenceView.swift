import SwiftUI

struct ReferenceView: View {
    @State private var viewModel = ReferenceViewModel()
    @State private var selectedTab: Int
    private let settingsStore: AppSettingsStore

    var embedded: Bool

    init(embedded: Bool = false, settingsStore: AppSettingsStore = AppSettingsStore()) {
        self.embedded = embedded
        self.settingsStore = settingsStore
        _selectedTab = State(initialValue: settingsStore.selectedReferenceTab)
    }

    var body: some View {
        if embedded {
            referenceContent
        } else {
            NavigationStack {
                referenceContent
            }
        }
    }

    private var referenceContent: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                Text("Quick Phrases").tag(0)
                Text("Vocabulary").tag(1)
                Text("Culture").tag(2)
                Text("Numbers").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case 0:
                phrasesView
            case 1:
                vocabularyView
            case 2:
                cultureView
            case 3:
                numbersView
            default:
                EmptyView()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reference")
        .searchable(text: $viewModel.searchText, prompt: "Search...")
        .onChange(of: selectedTab) { _, newValue in
            settingsStore.selectedReferenceTab = newValue
        }
    }
    
    private var phrasesView: some View {
        List {
            ForEach(viewModel.phraseSections) { section in
                Section(section.title) {
                    ForEach(section.phrases) { phrase in
                        PhraseReferenceRow(phrase: phrase)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var vocabularyView: some View {
        VStack(spacing: 0) {
            categoryFilter
            
            List {
                ForEach(viewModel.vocabulary) { word in
                    VocabularyReferenceRow(word: word)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectCategory(nil)
                }

                ForEach(viewModel.vocabularyCategories, id: \.self) { category in
                    CategoryChip(title: category, isSelected: viewModel.selectedCategory == category) {
                        viewModel.selectCategory(category)
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var numbersView: some View {
        List {
            Section("Numbers") {
                ForEach(viewModel.numbers, id: \.value) { number in
                    NumberRow(number: number)
                }
            }

            Section("Months") {
                ForEach(viewModel.ethiopianMonths, id: \.month) { month in
                    ReferencePairRow(
                        leading: month.amharic,
                        primary: month.transliteration,
                        secondary: month.gregorian
                    )
                }
            }

            Section("Ordinals") {
                ForEach(viewModel.ordinalNumbers, id: \.value) { ordinal in
                    ReferencePairRow(
                        leading: ordinal.amharic,
                        primary: ordinal.transliteration,
                        secondary: "\(ordinal.value)"
                    )
                }
            }

            Section("Fractions") {
                ForEach(viewModel.fractions, id: \.english) { fraction in
                    ReferencePairRow(
                        leading: fraction.amharic,
                        primary: fraction.transliteration,
                        secondary: fraction.english
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var cultureView: some View {
        List {
            ForEach(viewModel.culturalNotes) { note in
                CulturalNoteReferenceRow(note: note)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct PhraseReferenceRow: View {
    let phrase: Phrase
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phrase.amharic)
                    .font(AppTheme.Typography.amharic(size: 20))
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
            }
            
            Text(phrase.transliteration)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text(phrase.english)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !phrase.notes.isEmpty {
                    Text("(\(phrase.notes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = phrase.amharic
        isCopied = true
        
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }
}

struct VocabularyReferenceRow: View {
    let word: VocabularyWord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.amharic)
                    .font(AppTheme.Typography.amharic(size: 18))
                Text(word.transliteration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(word.english)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(word.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppTheme.primaryColor.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct NumberRow: View {
    let number: AmharicNumber
    
    var body: some View {
        HStack {
            Text("\(number.value)")
                .font(.title2)
                .bold()
                .foregroundStyle(AppTheme.primaryColor)
                .frame(width: 50)
            
            Text(number.amharic)
                .font(AppTheme.Typography.amharic(size: 24))
            
            Spacer()
            
            Text(number.transliteration)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ReferencePairRow: View {
    let leading: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack {
            Text(leading)
                .font(AppTheme.Typography.amharic(size: 22))

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(primary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CulturalNoteReferenceRow: View {
    let note: CulturalNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: note.icon)
                .font(.title3)
                .foregroundStyle(AppTheme.primaryColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(note.title)
                    .font(AppTheme.Typography.headline)

                Text(note.amharicTitle)
                    .font(AppTheme.Typography.amharic(size: 18))
                    .foregroundStyle(AppTheme.primaryColor)

                Text(note.content)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.primaryColor : Color(.systemGray5))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

#Preview {
    ReferenceView()
}
