import Foundation

/// Logging helper that writes to stderr and flushes immediately
private func debugLog(_ message: String) {
    let line = "StarCmd [SessionManager]: \(message)\n"
    FileHandle.standardError.write(Data(line.utf8))
}

/// Manages Claude Code sessions and their states
/// Sessions are keyed by tmux pane ID to avoid stale sessions when SessionEnd doesn't fire.
public actor SessionManager {
    /// Sessions keyed by pane ID (e.g. "%5")
    public private(set) var sessions: [String: ClaudeSession] = [:]

    /// Reverse lookup: sessionId → paneId
    private var sessionIdToPaneId: [String: String] = [:]

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
        case .list:
            break // handled externally via listSessionsData()
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

    /// Returns JSON array of all sessions for the list endpoint
    public func listSessionsData() -> Data {
        struct SessionInfo: Encodable {
            let sessionId: String
            let paneId: String
            let status: String
            let cwd: String
            let tmux: String
            let registeredAt: Int
            let lastActivityAt: Int
            let lastNotification: NotificationInfo?

            struct NotificationInfo: Encodable {
                let message: String
                let type: String
                let lastMessage: String?
            }
        }

        let infos = sessions.map { (paneId, session) in
            SessionInfo(
                sessionId: session.id,
                paneId: paneId,
                status: session.status.rawValue,
                cwd: session.cwd,
                tmux: session.tmuxContext.displayName,
                registeredAt: Int(session.registeredAt.timeIntervalSince1970),
                lastActivityAt: Int(session.lastActivityAt.timeIntervalSince1970),
                lastNotification: session.lastNotification.map {
                    SessionInfo.NotificationInfo(
                        message: $0.message,
                        type: $0.type.rawValue,
                        lastMessage: $0.lastMessage
                    )
                }
            )
        }

        return (try? JSONEncoder().encode(infos)) ?? Data("[]".utf8)
    }

    // MARK: - Message Handlers

    private func handleRegister(_ msg: RegisterMessage) {
        guard let tmuxContext = TmuxContext(from: msg.tmux) else {
            debugLog("register: ignoring session \(msg.sessionId) — invalid tmux context '\(msg.tmux)'")
            return
        }

        let paneId = tmuxContext.paneId

        // If a different session already owns this pane, evict it
        if let existing = sessions[paneId], existing.id != msg.sessionId {
            debugLog("register: evicting session \(existing.id) from pane \(paneId) (replaced by \(msg.sessionId))")
            sessionIdToPaneId.removeValue(forKey: existing.id)
        }

        // If this sessionId was previously on a different pane, clean up that mapping
        if let oldPaneId = sessionIdToPaneId[msg.sessionId], oldPaneId != paneId {
            debugLog("register: session \(msg.sessionId) moved from pane \(oldPaneId) to \(paneId)")
            sessions.removeValue(forKey: oldPaneId)
        }

        let session = ClaudeSession(
            id: msg.sessionId,
            tmuxContext: tmuxContext,
            cwd: msg.cwd,
            status: .working,
            registeredAt: Date(timeIntervalSince1970: TimeInterval(msg.timestamp)),
            lastActivityAt: Date()
        )

        sessions[paneId] = session
        sessionIdToPaneId[msg.sessionId] = paneId
        debugLog("register: session \(msg.sessionId) in pane \(paneId) (\(tmuxContext.displayName))")
    }

    private func handleNotification(_ msg: NotificationMessage) {
        guard let paneId = sessionIdToPaneId[msg.sessionId],
              var session = sessions[paneId] else {
            debugLog("notification: unknown session \(msg.sessionId)")
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

        sessions[paneId] = session
        debugLog("notification: session \(msg.sessionId) → \(newStatus) (\(msg.notificationType))")
    }

    private func handleClear(_ msg: ClearMessage) {
        guard let paneId = sessionIdToPaneId[msg.sessionId],
              var session = sessions[paneId] else {
            debugLog("clear: unknown session \(msg.sessionId)")
            return
        }

        session.status = .working
        session.lastNotification = nil
        session.lastActivityAt = Date()

        sessions[paneId] = session
        debugLog("clear: session \(msg.sessionId) → working")
    }

    private func handleDeregister(_ msg: DeregisterMessage) {
        guard let paneId = sessionIdToPaneId[msg.sessionId] else {
            debugLog("deregister: unknown session \(msg.sessionId)")
            return
        }

        sessions.removeValue(forKey: paneId)
        sessionIdToPaneId.removeValue(forKey: msg.sessionId)
        debugLog("deregister: session \(msg.sessionId) from pane \(paneId)")
    }
}
