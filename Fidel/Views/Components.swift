import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?

    init(icon: String, title: String, message: String, action: (() -> Void)? = nil, actionTitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionTitle = actionTitle
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.primaryColor.opacity(0.6), AppTheme.secondaryColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, AppTheme.Spacing.xs)

            Text(title)
                .font(AppTheme.Typography.title2)
                .foregroundStyle(AppTheme.inkColor)

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.inkSecondaryColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                }
                .primaryGlassButton()
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Claude Design Primitives

struct FidelPaperBackground: View {
    var body: some View {
        ZStack {
            AppTheme.paperColor
            RadialGradient(
                colors: [AppTheme.terracottaColor.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 360
            )
            RadialGradient(
                colors: [AppTheme.eucalyptusColor.opacity(0.13), .clear],
                center: .bottomLeading,
                startRadius: 12,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

struct FidelDesignCard<Content: View>: View {
    var padding: CGFloat = AppTheme.Spacing.md
    var cornerRadius: CGFloat = 22
    var background: Color = AppTheme.cardColor
    var borderColor: Color = AppTheme.hairlineColor
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 2)
    }
}

struct FidelSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTheme.Typography.caption2.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(AppTheme.terracottaColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FidelProgressBar: View {
    var value: Double
    var color: Color = AppTheme.terracottaColor
    var trackColor: Color = AppTheme.paperAccentColor
    var height: CGFloat = 6

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((clampedValue * 100).rounded())) percent")
    }
}

struct FidelChip: View {
    let title: String
    var isSelected = false
    var color: Color = AppTheme.inkColor

    var body: some View {
        Text(title)
            .font(AppTheme.Typography.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? AppTheme.onAccentColor : color)
            .background(isSelected ? color : AppTheme.cardColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? .clear : AppTheme.hairlineColor, lineWidth: 1)
            }
    }
}

struct FidelQuickActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = AppTheme.paperAccentColor
    var iconColor: Color = AppTheme.terracottaColor
    var textColor: Color = AppTheme.inkColor
    var subtitleColor: Color = AppTheme.mutedInkColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.onAccentColor)
                    .frame(width: 34, height: 34)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.hairlineColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

struct FidelMetricTile: View {
    let icon: String
    let value: String
    let label: String
    var subtitle: String?
    var color: Color = AppTheme.terracottaColor
    var background: Color = AppTheme.cardColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.inkColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.inkSecondaryColor)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppTheme.Typography.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fidelDesignCard(background: background)
        .accessibilityElement(children: .combine)
    }
}

struct FidelScreenHeader: View {
    var eyebrow: String?
    let title: String
    var amharicTitle: String?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                FidelSectionLabel(title: eyebrow)
            }

            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.inkColor)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            if let amharicTitle {
                Text(amharicTitle)
                    .font(AppTheme.Typography.amharicDisplay(size: 22, relativeTo: .title3))
                    .foregroundStyle(AppTheme.terracottaDeepColor)
            }

            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.mutedInkColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared Interaction Primitives

struct LearningCardButton<Content: View>: View {
    let accessibilityLabel: String
    var accessibilityHint: String?
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .frame(minHeight: 44)
    }
}

private struct PracticeCanvasWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AdaptivePracticeCanvas<Content: View>: View {
    let idealSize: CGSize
    var minimumSide: CGFloat = 240
    var onSizeChange: (CGSize) -> Void = { _ in }
    @ViewBuilder let content: (CGSize) -> Content

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let size = fittedSize(for: availableWidth, idealSize: idealSize, minimumSide: minimumSide)

        ZStack {
            content(size)
                .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: PracticeCanvasWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(PracticeCanvasWidthKey.self) { newWidth in
            availableWidth = newWidth
            onSizeChange(fittedSize(for: newWidth, idealSize: idealSize, minimumSide: minimumSide))
        }
        .accessibilityElement(children: .contain)
    }

    static func fittedSize(for availableWidth: CGFloat, idealSize: CGSize, minimumSide: CGFloat = 240) -> CGSize {
        guard idealSize.width > 0, idealSize.height > 0 else { return .zero }
        let usableWidth = availableWidth > 0 ? availableWidth : idealSize.width
        let cappedWidth = min(idealSize.width, usableWidth)
        let fittedWidth = usableWidth < minimumSide ? max(1, usableWidth) : max(minimumSide, cappedWidth)
        let scale = fittedWidth / idealSize.width
        return CGSize(width: fittedWidth, height: idealSize.height * scale)
    }

    private func fittedSize(for availableWidth: CGFloat, idealSize: CGSize, minimumSide: CGFloat) -> CGSize {
        Self.fittedSize(for: availableWidth, idealSize: idealSize, minimumSide: minimumSide)
    }
}

struct InfoCard: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.inkColor)

                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.inkSecondaryColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInkColor)
        }
        .glassCard()
    }
}

struct AmharicTextView: View {
    let amharic: String
    let transliteration: String
    let english: String
    let showAll: Bool

    init(amharic: String, transliteration: String, english: String, showAll: Bool = true) {
        self.amharic = amharic
        self.transliteration = transliteration
        self.english = english
        self.showAll = showAll
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(amharic)
                .font(AppTheme.Typography.amharic(size: 32))
                .foregroundStyle(AppTheme.primaryColor)

            if showAll {
                Text(transliteration)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.inkSecondaryColor)

                Text(english)
                    .font(AppTheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.inkColor)
            }
        }
    }
}

struct CountdownTimer: View {
    let seconds: Int

    private var progress: Double {
        min(Double(seconds) / 60.0, 1.0)
    }

    private var color: Color {
        seconds < 10 ? AppTheme.accentRed : AppTheme.primaryColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.inkColor.opacity(0.08), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: seconds)

            Text("\(seconds)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: 64, height: 64)
    }
}

struct GlassChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(isSelected ? AppTheme.onAccentColor : AppTheme.inkColor)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background {
                    if isSelected {
                        Capsule().fill(AppTheme.primaryColor)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : AppTheme.inkColor.opacity(0.1),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, AppTheme.Spacing.xs)
        .padding(.vertical, AppTheme.Spacing.xxs)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

struct GlassProgressBar: View {
    let progress: Double
    var height: CGFloat = 8
    var showGradient: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppTheme.inkColor.opacity(0.08))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        showGradient
                            ? LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.primaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: max(0, geometry.size.width * min(progress, 1.0)))
                    .animation(AppTheme.Animation.gentle, value: progress)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            EmptyStateView(
                icon: "book.closed",
                title: "No Content",
                message: "Start learning to see content here",
                action: {},
                actionTitle: "Start Learning"
            )

            InfoCard(
                icon: "flame.fill",
                title: "5 Day Streak",
                subtitle: "Keep it up!",
                color: AppTheme.warningColor
            )
            .padding(.horizontal)

            AmharicTextView(
                amharic: "ጤና ይስጥልኝ",
                transliteration: "t'ena yist'illiany",
                english: "Hello"
            )

            HStack {
                GlassChip(title: "All", isSelected: true, action: {})
                GlassChip(title: "Greetings", isSelected: false, action: {})
                GlassChip(title: "Numbers", isSelected: false, action: {})
            }

            GlassProgressBar(progress: 0.65)
                .padding(.horizontal)

            CountdownTimer(seconds: 45)
        }
        .padding()
    }
    .background(AppTheme.groupedBackground)
}
