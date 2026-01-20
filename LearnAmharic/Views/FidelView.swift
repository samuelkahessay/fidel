import SwiftUI

struct FidelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCharacter: FidelCharacter?
    @State private var searchText = ""
    
    let vowelHeaders = ["ä", "u", "i", "a", "e", "ə", "o"]
    
    var filteredChart: [[FidelCharacter]] {
        if searchText.isEmpty {
            return AmharicData.fidelChart
        }
        return AmharicData.fidelChart.map { row in
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
                
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        vowelHeaderRow
                        
                        ForEach(Array(filteredChart.enumerated()), id: \.offset) { _, row in
                            if !row.isEmpty {
                                FidelRow(characters: row, selectedCharacter: $selectedCharacter)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Fidel Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("ፊደል - Fidel")
                .font(.title2.bold())
            
            Text("The Ethiopic Script has 34 basic consonants, each with 7 vowel forms")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(AppTheme.primaryColor.opacity(0.1))
    }
    
    private var vowelHeaderRow: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 50)
            
            ForEach(0..<7) { index in
                Text(vowelHeaders[index])
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.primaryColor)
                    .frame(width: 60)
            }
        }
        .padding(.bottom, 8)
    }
}

struct FidelRow: View {
    let characters: [FidelCharacter]
    @Binding var selectedCharacter: FidelCharacter?
    
    var body: some View {
        HStack(spacing: 0) {
            if let first = characters.first {
                Text(first.consonant)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 50)
            }
            
            ForEach(characters) { char in
                FidelCell(character: char, isSelected: selectedCharacter?.id == char.id)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCharacter = char
                        }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
            }
        }
    }
}

struct FidelCell: View {
    let character: FidelCharacter
    let isSelected: Bool
    
    var body: some View {
        Text(character.character)
            .font(.system(size: 28))
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppTheme.primaryColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

struct CharacterDetailView: View {
    let character: FidelCharacter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text(character.character)
                .font(.system(size: 120))
                .foregroundColor(AppTheme.primaryColor)
            
            VStack(spacing: 8) {
                Text("Romanization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(character.romanization)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            HStack(spacing: 32) {
                VStack {
                    Text("Consonant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(character.consonant)
                        .font(.title2)
                }
                
                VStack {
                    Text("Vowel Form")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(character.vowelOrder)")
                        .font(.title2)
                }
            }
            
            Text("Pronunciation: \(character.audioHint)")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    }
}

#Preview {
    FidelView()
}
