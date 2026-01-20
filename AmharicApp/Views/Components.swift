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
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 4, y: 2)
        )
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
        VStack(spacing: 8) {
            Text(amharic)
                .font(.system(size: 28))
                .foregroundColor(AppTheme.primaryColor)
            
            if showAll {
                Text(transliteration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(english)
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
    }
}

struct SuccessOverlay: View {
    @Binding var isShowing: Bool
    let message: String
    let xpEarned: Int
    
    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    AnimatedCheckmark()
                    
                    Text(message)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    XPBadge(xp: xpEarned)
                    
                    Button("Continue") {
                        withAnimation {
                            isShowing = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                )
                .padding()
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
}

struct CountdownTimer: View {
    let seconds: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: CGFloat(seconds) / 60.0)
                .stroke(
                    seconds < 10 ? Color.red : AppTheme.primaryColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: seconds)
            
            Text("\(seconds)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(seconds < 10 ? .red : .primary)
        }
        .frame(width: 60, height: 60)
    }
}

#Preview {
    VStack(spacing: 20) {
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
        
        AmharicTextView(
            amharic: "ጤና ይስጥልኝ",
            transliteration: "t'ena yist'illiany",
            english: "Hello"
        )
    }
    .padding()
}
