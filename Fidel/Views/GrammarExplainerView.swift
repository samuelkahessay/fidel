import SwiftUI

/// Grammar reference: a teach-first explainer that groups the bundled grammar
/// patterns by topic and introduces each with a plain-English rule summary, then
/// shows the vetted structure and worked examples (with audio). Complements the
/// substitution/word-order drills, which practice grammar but never explain it.
struct GrammarExplainerView: View {
    @State private var viewModel = GrammarExplainerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("Understand the rules behind the sentences, then practice them in the drills.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.topics) { topic in
                    NavigationLink {
                        GrammarTopicDetailView(topic: topic)
                    } label: {
                        topicCard(topic)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("Grammar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
    }

    private func topicCard(_ topic: GrammarExplainerViewModel.Topic) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(topic.title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)
                Text(topic.blurb)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .lineLimit(2)
                Text("\(topic.patterns.count) pattern\(topic.patterns.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.primaryColor)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.cardColor)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Detail for one grammar topic: the English rule, then each pattern's structure
/// and worked examples with tap-to-hear Amharic.
struct GrammarTopicDetailView: View {
    let topic: GrammarExplainerViewModel.Topic

    @State private var audio = WordAudioPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                Text(topic.blurb)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.inkColor)
                    .padding(AppTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(AppTheme.primaryColor.opacity(0.08))
                    )

                ForEach(topic.patterns) { pattern in
                    patternCard(pattern)
                }
            }
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fidelTabBarHidden()
    }

    private func patternCard(_ pattern: Pattern) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(pattern.description)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.inkColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.structure)
                    .font(AppTheme.Typography.amharic(size: 22))
                    .foregroundStyle(AppTheme.primaryColor)
                Text(pattern.template)
                    .font(AppTheme.Typography.transliteration(size: 13))
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            if !pattern.examples.isEmpty {
                Divider()
                Text("Examples")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                    .textCase(.uppercase)
                ForEach(pattern.examples, id: \.amharic) { example in
                    exampleRow(example)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.cardColor)
        )
        .accessibilityElement(children: .contain)
    }

    private func exampleRow(_ example: Pattern.Example) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(example.amharic)
                    .font(AppTheme.Typography.amharic(size: 20))
                    .foregroundStyle(AppTheme.inkColor)
                Text(example.transliteration)
                    .font(AppTheme.Typography.transliteration(size: 12))
                    .foregroundStyle(AppTheme.inkSecondaryColor)
                Text(example.english)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }
            Spacer(minLength: 0)
            Button {
                audio.play(example.amharic)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.primaryColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play pronunciation")
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}

#Preview {
    NavigationStack {
        GrammarExplainerView()
    }
}
