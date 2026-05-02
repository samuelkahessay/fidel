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
        static let largeTitle = Font.system(size: 38, weight: .heavy)
        static let title = Font.system(size: 30, weight: .bold)
        static let title2 = Font.system(size: 24, weight: .bold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
        
        // Amharic display — Noto Sans Ethiopic for consistent rendering
        static func amharic(size: CGFloat) -> Font {
            .custom("NotoSansEthiopic-Regular", size: size)
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
        case 1: return .green
        case 2: return .orange
        case 3: return accentRed
        default: return .gray
        }
    }
    
    // MARK: - Glass Tints
    
    struct GlassTint {
        static let primary = primaryColor.opacity(0.08)
        static let secondary = secondaryColor.opacity(0.08)
        static let neutral = Color.primary.opacity(0.03)
    }
}

// MARK: - Glass Card Style

struct GlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var padding: CGFloat = AppTheme.Spacing.md
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                colorScheme == .dark
                                    ? AppTheme.primaryColor.opacity(0.35)
                                    : AppTheme.primaryColor.opacity(0.15),
                                lineWidth: 0.5
                            )
                    )
            )
    }
}

struct TintedGlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var tintColor: Color = AppTheme.primaryColor
    var tintOpacity: Double = 0.08
    var padding: CGFloat = AppTheme.Spacing.md
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tintColor.opacity(tintOpacity))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark
                            ? AppTheme.primaryColor.opacity(0.4)
                            : AppTheme.primaryColor.opacity(0.25),
                        lineWidth: 0.5
                    )
            )
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
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark
                            ? AppTheme.primaryColor.opacity(0.35)
                            : AppTheme.primaryColor.opacity(0.15),
                        lineWidth: 0.5
                    )
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
    var isFullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .tracking(1.2)
            .foregroundColor(.white)
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
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

/// Secondary button - Glass material background
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isFullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .tracking(1.2)
            .foregroundColor(AppTheme.primaryColor)
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
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

/// Ghost button - No background
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .tracking(1.2)
            .foregroundColor(AppTheme.primaryColor)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
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
    let streak: Int
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .foregroundColor(streak > 0 ? .orange : .secondary)
                .symbolEffect(.bounce, value: streak)
            
            Text("\(streak)")
                .font(AppTheme.Typography.headline)
                .foregroundColor(streak > 0 ? .orange : .secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(streak > 0 ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - XP Badge

struct XPBadge: View {
    let xp: Int
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: "star.fill")
                .foregroundColor(AppTheme.secondaryColor)
                .symbolEffect(.bounce, value: xp)
            
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
    }
}

// MARK: - Animated Checkmark

struct AnimatedCheckmark: View {
    @State private var isAnimated = false
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(
                LinearGradient(
                    colors: [.green, AppTheme.primaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(isAnimated ? 1.0 : 0.3)
            .opacity(isAnimated ? 1.0 : 0.0)
            .onAppear {
                withAnimation(AppTheme.Animation.standard) {
                    isAnimated = true
                }
            }
    }
}

// MARK: - Progress Ring (Gradient)

struct ProgressRing: View {
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
                .animation(AppTheme.Animation.gentle, value: progress)
            
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

// MARK: - Glass Segmented Control Style

struct GlassSegmentedStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
    }
}
