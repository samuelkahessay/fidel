import SwiftUI

// MARK: - Selam Avatar

struct SelamAvatarView: View {
    var size: CGFloat = 40
    var showBadge: Bool = false
    var badgeCount: Int = 0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text("ሰ")
                        .font(AppTheme.Typography.amharic(size: size * 0.5))
                        .foregroundStyle(AppTheme.onAccentColor)
                )
            
            if showBadge && badgeCount > 0 {
                Text("\(min(badgeCount, 99))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.onAccentColor)
                    .padding(4)
                    .background(Circle().fill(AppTheme.accentRed))
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: SelamMessage
    let isStreaming: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            if !isUser {
                SelamAvatarView(size: 32)
            } else {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: AppTheme.Spacing.xxs) {
                bubbleContent
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(bubbleBackground)
                    .clipShape(ChatBubbleShape(isUser: isUser))
                
                if !isUser && !message.isComplete && isStreaming {
                    TypingIndicatorView()
                        .padding(.leading, AppTheme.Spacing.xs)
                }
            }
            
            if isUser {
                Spacer().frame(width: 8)
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "You" : "Selam")
        .accessibilityValue(message.content.isEmpty && isStreaming ? "Typing" : message.content)
    }
    
    private var bubbleContent: some View {
        Text(message.content.isEmpty && isStreaming ? " " : message.content)
            .font(AppTheme.Typography.body)
            .foregroundStyle(isUser ? AppTheme.onAccentColor : AppTheme.inkColor)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .stroke(
                            AppTheme.hairlineColor,
                            lineWidth: 0.5
                        )
                )
        }
    }
}

struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isUser {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                       radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius - tailSize),
                       radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY - tailSize))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                             control: CGPoint(x: rect.maxX - tailSize/2, y: rect.maxY - tailSize/2))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                       radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                       radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                       radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                       radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius - tailSize),
                       radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - tailSize))
            path.addQuadCurve(to: CGPoint(x: rect.minX - tailSize, y: rect.maxY),
                             control: CGPoint(x: rect.minX - tailSize/2, y: rect.maxY - tailSize/2))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                       radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppTheme.primaryColor.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(reduceMotion ? 1.0 : scale(for: index))
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .onAppear { animationPhase = 1.0 }
        .accessibilityLabel("Selam is typing")
    }
    
    private func scale(for index: Int) -> CGFloat {
        animationPhase == 0 ? 0.5 : 1.0
    }
}

// MARK: - Chat Input

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            TextField("Message Selam...", text: $text, axis: .vertical)
                .font(AppTheme.Typography.body)
                .lineLimit(1...6)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                                .stroke(
                                    isFocused ? AppTheme.primaryColor.opacity(0.5) : AppTheme.hairlineColor,
                                    lineWidth: isFocused ? 2 : 0.5
                                )
                        )
                )
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading {
                        onSend()
                    }
                }
                .accessibilityLabel("Message Selam")
            
            sendButton
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: AppTheme.Shadow.elevated, radius: 10, y: -5)
        )
        .accessibilityElement(children: .contain)
    }
    
    @ViewBuilder
    private var sendButton: some View {
        Button(action: isLoading ? onCancel : onSend) {
            Image(systemName: isLoading ? "stop.fill" : "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    canSend || isLoading ? AppTheme.primaryColor : AppTheme.inkSecondaryColor.opacity(0.5)
                )
        }
        .accessibilityLabel(isLoading ? "Cancel" : "Send")
        .accessibilityHint(isLoading ? "Stops Selam's response" : "Sends your message to Selam")
        .disabled(!canSend && !isLoading)
        .frame(minWidth: 44, minHeight: 44)
        .animation(AppTheme.Animation.quick, value: isLoading)
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Suggested Actions

struct SuggestedActionsView: View {
    let actions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        if !actions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(actions, id: \.self) { action in
                        Button(action: { onSelect(action) }) {
                            Text(action)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.primaryColor)
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.primaryColor.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(AppTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Sends this suggested message")
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }
}

// MARK: - Previews

#Preview("Selam Avatar") {
    HStack(spacing: 20) {
        SelamAvatarView(size: 32)
        SelamAvatarView(size: 40)
        SelamAvatarView(size: 56, showBadge: true, badgeCount: 3)
    }
    .padding()
}

#Preview("Message Bubbles") {
    VStack(spacing: 8) {
        MessageBubbleView(
            message: {
                let m = SelamMessage(content: "ሰላም! How can I help you learn Amharic today?", role: .assistant)
                return m
            }(),
            isStreaming: false
        )
        
        MessageBubbleView(
            message: {
                let m = SelamMessage(content: "How do I say thank you?", role: .user)
                return m
            }(),
            isStreaming: false
        )
    }
    .padding()
    .background(AppTheme.groupedBackground)
}

#Preview("Typing Indicator") {
    TypingIndicatorView()
        .padding()
}

#Preview("Chat Input") {
    VStack {
        Spacer()
        ChatInputView(
            text: .constant(""),
            isLoading: false,
            onSend: {},
            onCancel: {}
        )
    }
}

#Preview("Suggested Actions") {
    SuggestedActionsView(
        actions: ["Teach me greetings", "Help with vocabulary", "Practice conversation"],
        onSelect: { _ in }
    )
    .padding()
}
