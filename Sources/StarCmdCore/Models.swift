import Foundation

// MARK: - Session Status

public enum SessionStatus: String, Codable, Equatable {
    case working   // Green - active, working normally
    case idle      // Yellow - idle_prompt, waiting for input
    case blocked   // Red - permission_prompt, requires action
}

// MARK: - Notification Type

public enum NotificationType: String, Codable, Equatable {
    case permissionPrompt = "permission_prompt"
    case idlePrompt = "idle_prompt"
    case elicitationDialog = "elicitation_dialog"

    public var resultingStatus: SessionStatus {
        switch self {
        case .permissionPrompt, .elicitationDialog:
            return .blocked
        case .idlePrompt:
            return .idle
        }
    }
}

// MARK: - Tmux Context

public struct TmuxContext: Codable, Equatable {
    public let session: String
    public let window: Int
    public let pane: Int

    public var displayName: String {
        "\(session):\(window):\(pane)"
    }

    public init(session: String, window: Int, pane: Int) {
        self.session = session
        self.window = window
        self.pane = pane
    }

    public init?(from string: String) {
        // Parse "session:window:pane" format
        let parts = string.split(separator: ":")
        guard parts.count == 3,
              let window = Int(parts[1]),
              let pane = Int(parts[2]) else {
            return nil
        }
        self.session = String(parts[0])
        self.window = window
        self.pane = pane
    }
}

// MARK: - Session Notification

public struct SessionNotification: Codable, Equatable {
    public let message: String
    public let type: NotificationType
    public let lastMessage: String?
    public let timestamp: Date

    public init(message: String, type: NotificationType, lastMessage: String?, timestamp: Date) {
        self.message = message
        self.type = type
        self.lastMessage = lastMessage
        self.timestamp = timestamp
    }
}

// MARK: - Claude Session

public struct ClaudeSession: Identifiable, Equatable {
    public let id: String
    public var tmuxContext: TmuxContext
    public var cwd: String
    public var status: SessionStatus
    public var lastNotification: SessionNotification?
    public let registeredAt: Date
    public var lastActivityAt: Date

    public init(
        id: String,
        tmuxContext: TmuxContext,
        cwd: String,
        status: SessionStatus = .working,
        lastNotification: SessionNotification? = nil,
        registeredAt: Date = Date(),
        lastActivityAt: Date = Date()
    ) {
        self.id = id
        self.tmuxContext = tmuxContext
        self.cwd = cwd
        self.status = status
        self.lastNotification = lastNotification
        self.registeredAt = registeredAt
        self.lastActivityAt = lastActivityAt
    }
}
