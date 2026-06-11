import SwiftUI

/// Brief sparkle burst shown when a character is completed: twelve particles
/// radiate from the center, scaling down and fading as they travel.
/// Under Reduce Motion the burst is skipped entirely (the canvas already
/// crossfades the glyph to the success color).
struct TraceCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let size: CGSize

    @State private var burst = false

    private let particleCount = 12

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    particle(at: index)
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    burst = true
                }
            }
        }
    }

    private func particle(at index: Int) -> some View {
        let angle = Double(index) / Double(particleCount) * 2 * .pi
        // Alternate radii so the burst reads organic rather than geometric.
        let travel = (index.isMultiple(of: 2) ? 0.34 : 0.26) * min(size.width, size.height)
        let color = index.isMultiple(of: 3) ? AppTheme.goldColor : AppTheme.successColor

        return Image(systemName: index.isMultiple(of: 4) ? "sparkle" : "circle.fill")
            .font(.system(size: index.isMultiple(of: 2) ? 11 : 7))
            .foregroundStyle(color)
            .opacity(burst ? 0 : 0.9)
            .scaleEffect(burst ? 0.4 : 1.0)
            .offset(
                x: burst ? cos(angle) * travel : 0,
                y: burst ? sin(angle) * travel : 0
            )
            .position(x: size.width / 2, y: size.height / 2)
    }
}

#Preview {
    TraceCelebrationView(size: CGSize(width: 300, height: 300))
        .background(AppTheme.groupedBackground)
}
