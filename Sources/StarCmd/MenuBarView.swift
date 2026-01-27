import SwiftUI
import StarCmdCore

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.sessions.isEmpty {
                noSessionsView
            } else {
                sessionListView
            }

            Divider()
                .padding(.vertical, 8)

            quitButton
        }
        .padding(.vertical, 8)
        .frame(width: 420)
    }

    // MARK: - Views

    private var noSessionsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Claude Code sessions")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a session to see it here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var sessionListView: some View {
        ForEach(appState.sessions) { session in
            SessionRow(session: session) {
                appState.focusSession(session)
            }
        }
    }

    private var quitButton: some View {
        Button("Quit StarCmd") {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ClaudeSession
    let onFocus: () -> Void

    @State private var isMessageExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row - session name is clickable to focus
            HStack(spacing: 8) {
                Button(action: onFocus) {
                    HStack(spacing: 8) {
                        StatusDot(status: session.status)

                        Text(session.tmuxContext.displayName)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.plain)
                .help("Focus in Ghostty")

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let elapsed = elapsedTime {
                    Text(elapsed)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Preview of notification message (if any)
            if let notification = session.lastNotification {
                notificationPreview(notification)
            }
        }
    }

    @ViewBuilder
    private func notificationPreview(_ notification: SessionNotification) -> some View {
        let message = notification.lastMessage ?? notification.message
        let hasLongMessage = message.count > 80

        VStack(alignment: .leading, spacing: 4) {
            if hasLongMessage {
                // Expandable message
                Button(action: { isMessageExpanded.toggle() }) {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: isMessageExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)

                        if isMessageExpanded {
                            Text(messageText(notification))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic(notification.lastMessage != nil)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text(truncate(messageText(notification), to: 60))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic(notification.lastMessage != nil)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // Short message, no expansion needed
                HStack(spacing: 4) {
                    Text(messageText(notification))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic(notification.lastMessage != nil)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.leading, 14)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.leading, 16)
    }

    private func messageText(_ notification: SessionNotification) -> String {
        if let lastMessage = notification.lastMessage, !lastMessage.isEmpty {
            return "\"\(lastMessage)\""
        }
        return notification.message
    }

    // MARK: - Helpers

    private var statusLabel: String {
        switch session.status {
        case .working:
            return "Working"
        case .idle:
            return "Idle"
        case .blocked:
            return "Blocked"
        }
    }

    private var elapsedTime: String? {
        guard let notification = session.lastNotification else { return nil }

        let elapsed = Date().timeIntervalSince(notification.timestamp)
        if elapsed < 60 {
            return "now"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes)m"
        } else {
            let hours = Int(elapsed / 3600)
            return "\(hours)h"
        }
    }

    private func truncate(_ string: String, to length: Int) -> String {
        if string.count <= length {
            return string
        }
        return String(string.prefix(length)) + "..."
    }

    private func abbreviatePath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

// MARK: - Status Dot

struct StatusDot: View {
    let status: SessionStatus

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch status {
        case .working:
            return .green
        case .idle:
            return .anthropicOrange
        case .blocked:
            return .red
        }
    }
}

