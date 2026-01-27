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
    public let session: String      // Session name
    public let window: String       // Window name (or index as fallback)
    public let paneId: String       // Absolute pane ID (e.g., %8)

    public var displayName: String {
        "\(session):\(window):\(paneId)"
    }

    public init(session: String, window: String, paneId: String) {
        self.session = session
        self.window = window
        self.paneId = paneId
    }

    public init?(from string: String) {
        // Parse "session:window:paneId" format
        // e.g., "main:editor:%8"
        let parts = string.split(separator: ":", maxSplits: 2)
        guard parts.count == 3 else {
            return nil
        }
        self.session = String(parts[0])
        self.window = String(parts[1])
        self.paneId = String(parts[2])
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
