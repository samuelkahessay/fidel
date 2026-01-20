import SwiftUI

struct ReferenceView: View {
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    var filteredPhrases: [Phrase] {
        if searchText.isEmpty {
            return AmharicData.phrases
        }
        return AmharicData.phrases.filter { phrase in
            phrase.amharic.contains(searchText) ||
            phrase.transliteration.lowercased().contains(searchText.lowercased()) ||
            phrase.english.lowercased().contains(searchText.lowercased())
        }
    }
    
    var filteredVocabulary: [VocabularyWord] {
        var words = AmharicData.vocabulary
        
        if let category = selectedCategory {
            words = words.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            words = words.filter { word in
                word.amharic.contains(searchText) ||
                word.transliteration.lowercased().contains(searchText.lowercased()) ||
                word.english.lowercased().contains(searchText.lowercased())
            }
        }
        
        return words
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    Text("Quick Phrases").tag(0)
                    Text("Vocabulary").tag(1)
                    Text("Numbers").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                switch selectedTab {
                case 0:
                    phrasesView
                case 1:
                    vocabularyView
                case 2:
                    numbersView
                default:
                    EmptyView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reference")
            .searchable(text: $searchText, prompt: "Search...")
        }
    }
    
    private var phrasesView: some View {
        List {
            ForEach(groupedPhrases.keys.sorted(), id: \.self) { category in
                Section(category) {
                    ForEach(groupedPhrases[category] ?? []) { phrase in
                        PhraseReferenceRow(phrase: phrase)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var groupedPhrases: [String: [Phrase]] {
        Dictionary(grouping: filteredPhrases) { phrase -> String in
            if phrase.id <= 10 { return "Greetings" }
            if phrase.id <= 15 { return "Thanks & Apologies" }
            if phrase.id <= 25 { return "Questions" }
            if phrase.id <= 30 { return "Responses" }
            if phrase.id <= 35 { return "Wants & Needs" }
            if phrase.id <= 45 { return "Useful Phrases" }
            return "Emergency"
        }
    }
    
    private var vocabularyView: some View {
        VStack(spacing: 0) {
            categoryFilter
            
            List {
                ForEach(filteredVocabulary) { word in
                    VocabularyReferenceRow(word: word)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                
                ForEach(AmharicData.vocabularyCategories, id: \.self) { category in
                    CategoryChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var numbersView: some View {
        List {
            Section("1-10") {
                ForEach(AmharicData.numbers.prefix(10), id: \.value) { number in
                    NumberRow(number: number)
                }
            }
            
            Section("Tens") {
                ForEach(AmharicData.numbers.dropFirst(10), id: \.value) { number in
                    NumberRow(number: number)
                }
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
                    .font(.system(size: 20))
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(isCopied ? .green : .secondary)
                }
            }
            
            Text(phrase.transliteration)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(phrase.english)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !phrase.notes.isEmpty {
                    Text("(\(phrase.notes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
                    .font(.system(size: 18))
                Text(word.transliteration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(word.english)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(word.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
    let number: (amharic: String, transliteration: String, value: Int)
    
    var body: some View {
        HStack {
            Text("\(number.value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.primaryColor)
                .frame(width: 50)
            
            Text(number.amharic)
                .font(.system(size: 24))
            
            Spacer()
            
            Text(number.transliteration)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
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
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

#Preview {
    ReferenceView()
}
