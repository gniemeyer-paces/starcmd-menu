import SwiftUI
import StarCmdCore

struct StatusIcon: View {
    let status: SessionStatus

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 14))
    }

    private var symbolName: String {
        switch status {
        case .working:
            return "checkmark.circle"
        case .idle:
            return "ellipsis.circle"
        case .blocked:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Anthropic Orange Color (for session list)

extension Color {
    static let anthropicOrange = Color(red: 0.85, green: 0.45, blue: 0.25)
}
