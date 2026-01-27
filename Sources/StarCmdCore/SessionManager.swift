import Foundation

/// Manages Claude Code sessions and their states
public actor SessionManager {
    public private(set) var sessions: [String: ClaudeSession] = [:]

    public init() {}

    /// Handle an IPC message from a hook script
    public func handleMessage(_ message: IPCMessage) {
        switch message {
        case .register(let msg):
            handleRegister(msg)
        case .notification(let msg):
            handleNotification(msg)
        case .clear(let msg):
            handleClear(msg)
        case .deregister(let msg):
            handleDeregister(msg)
        }
    }

    /// Get the aggregate status across all sessions (worst status wins)
    public var aggregateStatus: SessionStatus {
        var hasIdle = false

        for session in sessions.values {
            switch session.status {
            case .blocked:
                return .blocked  // Red is highest priority
            case .idle:
                hasIdle = true
            case .working:
                continue
            }
        }

        return hasIdle ? .idle : .working
    }

    /// Get sessions sorted by last activity (most recent first)
    public var sortedSessions: [ClaudeSession] {
        sessions.values.sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    // MARK: - Message Handlers

    private func handleRegister(_ msg: RegisterMessage) {
        guard let tmuxContext = TmuxContext(from: msg.tmux) else {
            // Invalid tmux context - ignore registration
            return
        }

        let session = ClaudeSession(
            id: msg.sessionId,
            tmuxContext: tmuxContext,
            cwd: msg.cwd,
            status: .working,
            registeredAt: Date(timeIntervalSince1970: TimeInterval(msg.timestamp)),
            lastActivityAt: Date()
        )

        sessions[msg.sessionId] = session
    }

    private func handleNotification(_ msg: NotificationMessage) {
        guard var session = sessions[msg.sessionId] else {
            // Unknown session - could auto-register if we wanted
            return
        }

        // Determine status from notification type
        let notificationType = NotificationType(rawValue: msg.notificationType)
        let newStatus = notificationType?.resultingStatus ?? .idle

        // Create notification record
        let notification = SessionNotification(
            message: msg.message,
            type: notificationType ?? .idlePrompt,
            lastMessage: msg.lastMessage,
            timestamp: Date(timeIntervalSince1970: TimeInterval(msg.timestamp))
        )

        session.status = newStatus
        session.lastNotification = notification
        session.lastActivityAt = Date()

        // Update tmux context if it changed
        if let newContext = TmuxContext(from: msg.tmux) {
            session.tmuxContext = newContext
        }

        sessions[msg.sessionId] = session
    }

    private func handleClear(_ msg: ClearMessage) {
        guard var session = sessions[msg.sessionId] else {
            return
        }

        session.status = .working
        session.lastActivityAt = Date()

        sessions[msg.sessionId] = session
    }

    private func handleDeregister(_ msg: DeregisterMessage) {
        sessions.removeValue(forKey: msg.sessionId)
    }
}
