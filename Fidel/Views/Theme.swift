import SwiftUI

// MARK: - iOS 26 Liquid Glass Design System

/// App-wide design tokens following iOS 26 Liquid Glass design language
struct AppTheme {
    
    // MARK: - Colors (Ethiopian theme, modernized)
    
    /// Primary Ethiopian Green - Vibrant, modern
    static let primaryColor = Color(red: 0.0, green: 0.45, blue: 0.2)
    
    /// Secondary Ethiopian Gold - Clean, bright
    static let secondaryColor = Color(red: 1.0, green: 0.84, blue: 0.0)
    
    /// Accent Red - For errors/alerts only
    static let accentRed = Color(red: 0.81, green: 0.07, blue: 0.15)

    static let successColor = Color(red: 0.05, green: 0.53, blue: 0.22)
    static let warningColor = Color(red: 0.86, green: 0.47, blue: 0.0)
    static let infoColor = Color(red: 0.0, green: 0.42, blue: 0.85)
    static let practiceColor = Color(red: 0.33, green: 0.25, blue: 0.88)
    static let disabledColor = Color.secondary.opacity(0.55)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let surfaceColor = Color(.secondarySystemGroupedBackground)
    static let elevatedSurfaceColor = Color(.systemBackground)
    static let subtleSurfaceColor = Color(.tertiarySystemGroupedBackground)
    static let hairlineColor = Color.primary.opacity(0.10)
    static let subtleTextColor = Color.secondary
    
    /// Legacy color aliases
    static let ethiopianGreen = primaryColor
    static let ethiopianYellow = secondaryColor
    static let ethiopianRed = accentRed
    
    // MARK: - Spacing (4pt grid)
    
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Corner Radii (Concentric shapes)
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let pill: CGFloat = 100
    }
    
    // MARK: - Typography (SF Pro system)
    
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.heavy)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
        
        // Amharic display — Noto Sans Ethiopic for consistent rendering
        static func amharic(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
            .custom("NotoSansEthiopic-Regular", size: size, relativeTo: textStyle)
        }
    }
    
    // MARK: - Animations (Spring-based)
    
    struct Animation {
        static let springResponse: Double = 0.3
        static let springDamping: Double = 1.0
        static let quick: SwiftUI.Animation = .spring(response: 0.25, dampingFraction: 1.0)
        static let standard: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 1.0)
        static let gentle: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 1.0)
    }
    
    // MARK: - Difficulty Colors
    
    static func difficultyColor(_ level: Int) -> Color {
        switch level {
        case 1: return successColor
        case 2: return warningColor
        case 3: return accentRed
        default: return disabledColor
        }
    }
    
    // MARK: - Glass Tints
    
    struct GlassTint {
        static let primary = primaryColor.opacity(0.08)
        static let secondary = secondaryColor.opacity(0.08)
        static let neutral = Color.primary.opacity(0.03)
    }

    struct Shadow {
        static let card = Color.primary.opacity(0.06)
        static let elevated = Color.primary.opacity(0.08)
        static let bottomBar = Color.primary.opacity(0.10)
    }
}

// MARK: - Surface Styles

enum FidelSurfaceProminence {
    case solid
    case glass
    case tinted(Color, Double)
    case muted
}

struct FidelSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let prominence: FidelSurfaceProminence
    let padding: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        prominence: FidelSurfaceProminence = .solid,
        padding: CGFloat = AppTheme.Spacing.md,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.prominence = prominence
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background {
                background
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var background: some View {
        switch prominence {
        case .solid:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppTheme.elevatedSurfaceColor)
        case .glass:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
        case .tinted(let color, let opacity):
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark ? AppTheme.surfaceColor : AppTheme.elevatedSurfaceColor)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.opacity(opacity))
            }
        case .muted:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppTheme.surfaceColor)
        }
    }

    private var borderColor: Color {
        switch prominence {
        case .solid, .muted:
            return AppTheme.hairlineColor
        case .glass:
            return colorScheme == .dark ? Color.white.opacity(0.16) : AppTheme.primaryColor.opacity(0.16)
        case .tinted(let color, _):
            return color.opacity(colorScheme == .dark ? 0.42 : 0.24)
        }
    }
}

// MARK: - Glass Card Style

struct GlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var padding: CGFloat = AppTheme.Spacing.md
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    
    func body(content: Content) -> some View {
        FidelSurface(prominence: .glass, padding: padding, cornerRadius: cornerRadius) {
            content
        }
    }
}

struct TintedGlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var tintColor: Color = AppTheme.primaryColor
    var tintOpacity: Double = 0.08
    var padding: CGFloat = AppTheme.Spacing.md
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    
    func body(content: Content) -> some View {
        FidelSurface(prominence: .tinted(tintColor, tintOpacity), padding: padding, cornerRadius: cornerRadius) {
            content
        }
    }
}

// MARK: - Legacy Card Style (for compatibility)

struct EthiopianCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .modifier(GlassCardStyle())
    }
}

struct AdaptiveCardBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.elevatedSurfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.hairlineColor, lineWidth: 0.75)
            )
    }
}

// MARK: - Amharic Text Style

struct AmharicTextStyle: ViewModifier {
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.amharic(size: size))
    }
}

// MARK: - Button Styles

/// Primary button - Capsule shape, solid color
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isFullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, 14)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(AppTheme.primaryColor)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(reduceMotion ? nil : AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

/// Secondary button - Glass material background
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isFullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.primaryColor)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, 12)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : AppTheme.primaryColor.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(reduceMotion ? nil : AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

/// Ghost button - No background
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.primaryColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(reduceMotion ? nil : AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func fidelSurface(
        _ prominence: FidelSurfaceProminence = .solid,
        padding: CGFloat = AppTheme.Spacing.md,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large
    ) -> some View {
        FidelSurface(prominence: prominence, padding: padding, cornerRadius: cornerRadius) {
            self
        }
    }

    /// Apply glass card styling
    func glassCard(padding: CGFloat = AppTheme.Spacing.md, cornerRadius: CGFloat = AppTheme.CornerRadius.large) -> some View {
        modifier(GlassCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
    
    /// Apply tinted glass card styling
    func tintedGlassCard(
        tint: Color = AppTheme.primaryColor,
        tintOpacity: Double = 0.08,
        padding: CGFloat = AppTheme.Spacing.md,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large
    ) -> some View {
        modifier(TintedGlassCardStyle(
            tintColor: tint,
            tintOpacity: tintOpacity,
            padding: padding,
            cornerRadius: cornerRadius
        ))
    }
    
    /// Legacy ethiopian card style
    func ethiopianCard() -> some View {
        modifier(EthiopianCardStyle())
    }
    
    /// Apply Amharic text styling
    func amharicText(size: CGFloat = 24) -> some View {
        modifier(AmharicTextStyle(size: size))
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let streak: Int
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            badgeIcon
            
            Text("\(streak)")
                .font(AppTheme.Typography.headline)
            .foregroundColor(streak > 0 ? AppTheme.warningColor : .secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(streak > 0 ? AppTheme.warningColor.opacity(0.15) : Color.secondary.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak")
        .accessibilityValue("\(streak) days")
    }

    @ViewBuilder
    private var badgeIcon: some View {
        let image = Image(systemName: streak > 0 ? "flame.fill" : "flame")
            .foregroundColor(streak > 0 ? AppTheme.warningColor : .secondary)
        if reduceMotion {
            image
        } else {
            image.symbolEffect(.bounce, value: streak)
        }
    }
}

// MARK: - XP Badge

struct XPBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let xp: Int
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            badgeIcon
            
            Text("\(xp) XP")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.secondaryColor)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(AppTheme.secondaryColor.opacity(0.15))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Experience earned")
        .accessibilityValue("\(xp) XP")
    }

    @ViewBuilder
    private var badgeIcon: some View {
        let image = Image(systemName: "star.fill")
            .foregroundColor(AppTheme.secondaryColor)
        if reduceMotion {
            image
        } else {
            image.symbolEffect(.bounce, value: xp)
        }
    }
}

// MARK: - Difficulty Stars

struct DifficultyStars: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Image(systemName: index < level ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(index < level ? AppTheme.difficultyColor(level) : .secondary.opacity(0.3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulty")
        .accessibilityValue("\(level) out of 3")
    }
}

// MARK: - Animated Checkmark

struct AnimatedCheckmark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(
                LinearGradient(
                    colors: [AppTheme.successColor, AppTheme.primaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(isAnimated ? 1.0 : 0.3)
            .opacity(isAnimated ? 1.0 : 0.0)
            .onAppear {
                withAnimation(reduceMotion ? nil : AppTheme.Animation.standard) {
                    isAnimated = true
                }
            }
            .accessibilityLabel("Success")
    }
}

// MARK: - Progress Ring (Gradient)

struct ProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    var lineWidth: CGFloat = 8
    var size: CGFloat = 80
    var showPercentage: Bool = false
    
    private var gradientColors: [Color] {
        [AppTheme.primaryColor, AppTheme.secondaryColor]
    }
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            
            // Progress arc with gradient
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : AppTheme.Animation.gentle, value: progress)
            
            // Percentage text
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct AccessibleProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var size: CGFloat = 80
    var label: String
    var valueText: String?
    var showPercentage: Bool = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ProgressRing(
            progress: clampedProgress,
            lineWidth: lineWidth,
            size: size,
            showPercentage: showPercentage
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText ?? "\(Int(clampedProgress * 100)) percent")
    }
}

// MARK: - Glass Segmented Control Style

struct GlassSegmentedStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
    }
}

// MARK: - Root Tab Bar Visibility

struct FidelTabBarHiddenPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func fidelTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: FidelTabBarHiddenPreferenceKey.self, value: hidden)
    }
}
