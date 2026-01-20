import SwiftUI

struct AppTheme {
    static let primaryColor = Color(red: 0.0, green: 0.45, blue: 0.2)
    static let secondaryColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    static let accentRed = Color(red: 0.85, green: 0.11, blue: 0.09)
    static let ethiopianGreen = Color(red: 0.0, green: 0.45, blue: 0.2)
    static let ethiopianYellow = Color(red: 0.98, green: 0.80, blue: 0.08)
    static let ethiopianRed = Color(red: 0.85, green: 0.11, blue: 0.09)
    static let cardShadow = Color.black.opacity(0.08)
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor.opacity(0.1), secondaryColor.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor.opacity(0.15), secondaryColor.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func difficultyColor(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .gray
        }
    }
}

struct EthiopianCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
    }
}

struct AdaptiveCardBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : .clear, lineWidth: 1)
            )
    }
}

struct AmharicTextStyle: ViewModifier {
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium, design: .rounded))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryColor)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.primaryColor, lineWidth: 2)
            )
            .foregroundColor(AppTheme.primaryColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func ethiopianCard() -> some View {
        modifier(EthiopianCardStyle())
    }
    
    func amharicText(size: CGFloat = 24) -> some View {
        modifier(AmharicTextStyle(size: size))
    }
}

struct StreakBadge: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .foregroundColor(streak > 0 ? .orange : .gray)
            Text("\(streak)")
                .font(.headline)
                .foregroundColor(streak > 0 ? .orange : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(streak > 0 ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
        )
    }
}

struct XPBadge: View {
    let xp: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundColor(AppTheme.secondaryColor)
            Text("\(xp) XP")
                .font(.headline)
                .foregroundColor(AppTheme.secondaryColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.secondaryColor.opacity(0.2))
        )
    }
}

struct DifficultyStars: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Image(systemName: index < level ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundColor(index < level ? AppTheme.difficultyColor(level) : .gray.opacity(0.3))
            }
        }
    }
}

struct AnimatedCheckmark: View {
    @State private var isAnimated = false
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(.green)
            .scaleEffect(isAnimated ? 1.0 : 0.5)
            .opacity(isAnimated ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isAnimated = true
                }
            }
    }
}

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppTheme.primaryColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}
