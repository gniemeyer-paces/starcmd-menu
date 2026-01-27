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
        .frame(width: 320)
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

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    StatusDot(status: session.status)

                    Text(session.tmuxContext.displayName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)

                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let elapsed = elapsedTime {
                        Text(elapsed)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                expandedContent
            }
        }
        .background(isExpanded ? Color.primary.opacity(0.05) : Color.clear)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Notification message
            if let notification = session.lastNotification {
                if let lastMessage = notification.lastMessage, !lastMessage.isEmpty {
                    Text("\"\(truncate(lastMessage, to: 100))\"")
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .italic()
                } else {
                    Text(notification.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            // Working directory
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.caption)
                Text(abbreviatePath(session.cwd))
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)

            // Focus button
            Button(action: onFocus) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.square")
                    Text("Focus in Ghostty")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.leading, 24)
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

