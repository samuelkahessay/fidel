import SwiftUI
import UIKit

// MARK: - iOS 26 Liquid Glass Design System

/// App-wide design tokens following iOS 26 Liquid Glass design language
struct AppTheme {
    
    // MARK: - Colors (Ethiopian theme, modernized)
    
    static let paperColor = adaptiveColor(
        light: (0.965, 0.941, 0.894),
        dark: (0.115, 0.081, 0.061)
    )
    static let paperAccentColor = adaptiveColor(
        light: (0.937, 0.906, 0.835),
        dark: (0.170, 0.124, 0.092)
    )
    static let cardColor = adaptiveColor(
        light: (1.000, 0.992, 0.965),
        dark: (0.224, 0.164, 0.120)
    )
    static let inkColor = adaptiveColor(
        light: (0.133, 0.110, 0.086),
        dark: (0.965, 0.925, 0.850)
    )
    static let inkSecondaryColor = adaptiveColor(
        light: (0.290, 0.247, 0.200),
        dark: (0.828, 0.756, 0.650)
    )
    static let mutedInkColor = adaptiveColor(
        light: (0.490, 0.435, 0.369),
        dark: (0.704, 0.626, 0.522)
    )
    static let terracottaColor = adaptiveColor(
        light: (0.710, 0.318, 0.188),
        dark: (0.790, 0.374, 0.236)
    )
    static let terracottaDeepColor = adaptiveColor(
        light: (0.494, 0.214, 0.133),
        dark: (0.925, 0.560, 0.395)
    )
    static let eucalyptusColor = adaptiveColor(
        light: (0.294, 0.478, 0.392),
        dark: (0.345, 0.596, 0.472)
    )
    static let goldColor = adaptiveColor(
        light: (0.811, 0.605, 0.180),
        dark: (0.902, 0.690, 0.268)
    )
    static let plumColor = adaptiveColor(
        light: (0.298, 0.196, 0.180),
        dark: (0.704, 0.406, 0.352)
    )

    /// Primary design accent from the Claude Design handoff.
    static let primaryColor = terracottaColor

    /// Secondary accent used for progress and achievement emphasis.
    static let secondaryColor = goldColor

    /// Accent Red - For errors/alerts only
    static let accentRed = adaptiveColor(
        light: (0.760, 0.190, 0.140),
        dark: (0.930, 0.370, 0.300)
    )

    static let successColor = eucalyptusColor
    static let warningColor = goldColor
    static let infoColor = terracottaDeepColor
    static let practiceColor = plumColor
    static let disabledColor = mutedInkColor.opacity(0.58)
    static let groupedBackground = paperColor
    static let surfaceColor = paperAccentColor
    static let elevatedSurfaceColor = cardColor
    static let subtleSurfaceColor = adaptiveColor(
        light: (0.976, 0.953, 0.902),
        dark: (0.190, 0.139, 0.104)
    )
    static let hairlineColor = adaptiveColor(
        light: (0.875, 0.824, 0.733),
        dark: (0.363, 0.273, 0.205)
    )
    static let subtleTextColor = mutedInkColor
    static let onAccentColor = adaptiveColor(
        light: (1.000, 0.973, 0.910),
        dark: (1.000, 0.946, 0.850)
    )
    static let onGoldColor = adaptiveColor(
        light: (0.133, 0.110, 0.086),
        dark: (0.115, 0.081, 0.061)
    )
    
    /// Legacy color aliases
    static let ethiopianGreen = eucalyptusColor
    static let ethiopianYellow = goldColor
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
        
        // Amharic body — Noto Sans Ethiopic for consistent rendering
        static func amharic(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
            .custom("NotoSansEthiopic-Regular", size: size, relativeTo: textStyle)
        }

        static func amharicDisplay(size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> Font {
            .custom("NotoSerifEthiopic-Regular", size: size, relativeTo: textStyle)
        }

        static func transliteration(size: CGFloat, relativeTo textStyle: Font.TextStyle = .caption) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
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
        static let neutral = inkColor.opacity(0.03)
    }

    struct Shadow {
        static let card = Color.black.opacity(0.14)
        static let elevated = Color.black.opacity(0.20)
        static let bottomBar = Color.black.opacity(0.26)
    }

    private static func adaptiveColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double),
        alpha: Double = 1
    ) -> Color {
        Color(UIColor { traitCollection in
            let values = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(values.0),
                green: CGFloat(values.1),
                blue: CGFloat(values.2),
                alpha: CGFloat(alpha)
            )
        })
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
            return AppTheme.hairlineColor
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

    func fidelDesignCard(
        padding: CGFloat = AppTheme.Spacing.md,
        cornerRadius: CGFloat = 22,
        background: Color = AppTheme.cardColor,
        borderColor: Color = AppTheme.hairlineColor
    ) -> some View {
        FidelDesignCard(
            padding: padding,
            cornerRadius: cornerRadius,
            background: background,
            borderColor: borderColor
        ) {
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
    
    /// Apply Amharic text styling
    func amharicText(size: CGFloat = 24) -> some View {
        modifier(AmharicTextStyle(size: size))
    }

    /// Primary call-to-action as a native prominent Liquid Glass button.
    /// Tint is inherited from the app accent set on the root `TabView`.
    func primaryGlassButton(fullWidth: Bool = false) -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .frame(maxWidth: fullWidth ? .infinity : nil)
    }

    /// Secondary action as a native translucent Liquid Glass button.
    func secondaryGlassButton(fullWidth: Bool = false) -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .frame(maxWidth: fullWidth ? .infinity : nil)
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
            .foregroundStyle(streak > 0 ? AppTheme.warningColor : .secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(streak > 0 ? AppTheme.warningColor.opacity(0.15) : AppTheme.inkSecondaryColor.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak")
        .accessibilityValue("\(streak) days")
    }

    @ViewBuilder
    private var badgeIcon: some View {
        let image = Image(systemName: streak > 0 ? "flame.fill" : "flame")
            .foregroundStyle(streak > 0 ? AppTheme.warningColor : .secondary)
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
                .foregroundStyle(AppTheme.secondaryColor)
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
            .foregroundStyle(AppTheme.secondaryColor)
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
                    .foregroundStyle(index < level ? AppTheme.difficultyColor(level) : AppTheme.mutedInkColor.opacity(0.45))
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
                .stroke(AppTheme.inkColor.opacity(0.08), lineWidth: lineWidth)
            
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
                    .foregroundStyle(AppTheme.inkColor)
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

/// Solid gold accent ring with a minimum-visible arc, used by the level/goal rings.
/// Distinct from `ProgressRing` (which is an animated gradient ring).
struct GoldProgressRing<Content: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 9
    var size: CGFloat = 78
    var accessibilityLabel: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.goldColor.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    AppTheme.goldColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            content
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
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
