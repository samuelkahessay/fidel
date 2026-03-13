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
                .foregroundStyle(.primary)
            
            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .padding(AppTheme.Spacing.xl)
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.primaryColor)
            
            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(title: String, action: (() -> Void)? = nil, actionTitle: String? = nil) {
        self.title = title
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.title3)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.primaryColor)
                }
            }
        }
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
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                    .foregroundStyle(.secondary)
                
                Text(english)
                    .font(AppTheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct SuccessOverlay: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isShowing: Bool
    let message: String
    let xpEarned: Int
    
    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(AppTheme.Animation.standard) {
                            isShowing = false
                        }
                    }
                
                VStack(spacing: AppTheme.Spacing.lg) {
                    AnimatedCheckmark()
                    
                    Text(message)
                        .font(AppTheme.Typography.title2)
                        .foregroundStyle(.primary)
                    
                    XPBadge(xp: xpEarned)
                    
                    Button("Continue") {
                        withAnimation(AppTheme.Animation.standard) {
                            isShowing = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.Spacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xlarge)
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.15)
                                        : Color.black.opacity(0.05),
                                    lineWidth: 0.5
                                )
                        )
                )
                .padding(AppTheme.Spacing.xl)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
                .stroke(Color.primary.opacity(0.08), lineWidth: 4)
            
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
                .foregroundStyle(isSelected ? .white : .primary)
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
                            isSelected ? Color.clear : Color.primary.opacity(0.1),
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

struct GlassTextField: View {
    @Environment(\.colorScheme) var colorScheme
    let placeholder: String
    @Binding var text: String
    var alignment: TextAlignment = .center
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(AppTheme.Typography.title3)
            .multilineTextAlignment(alignment)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.08),
                                lineWidth: 0.5
                            )
                    )
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
                    .fill(Color.primary.opacity(0.08))
                
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
                color: .orange
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
    .background(Color(.systemGroupedBackground))
}
