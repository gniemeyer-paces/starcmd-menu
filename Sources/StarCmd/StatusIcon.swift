import SwiftUI
import StarCmdCore

struct StatusIcon: View {
    let status: SessionStatus
    @State private var isGlowing = false

    var body: some View {
        ZStack {
            // Use a filled circle with explicit color
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            // Half-fill overlay for idle status
            if status == .idle {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .mask(
                        Rectangle()
                            .frame(width: 6, height: 12)
                            .offset(x: 3)
                    )
            }
        }
        .opacity(needsAttention ? (isGlowing ? 1.0 : 0.6) : 1.0)
        .animation(needsAttention ? glowAnimation : nil, value: isGlowing)
        .onAppear {
            if needsAttention {
                isGlowing = true
            }
        }
        .onChange(of: status) { newStatus in
            isGlowing = newStatus != .working
        }
    }

    private var statusColor: Color {
        switch status {
        case .working:
            return .green
        case .idle:
            return Color.anthropicOrange
        case .blocked:
            return .red
        }
    }

    private var needsAttention: Bool {
        status != .working
    }

    private var glowAnimation: Animation {
        .easeInOut(duration: 1.0)
        .repeatForever(autoreverses: true)
    }
}

// MARK: - Anthropic Orange Color

extension Color {
    static let anthropicOrange = Color(red: 0.85, green: 0.45, blue: 0.25)
}
