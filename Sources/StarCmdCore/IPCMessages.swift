import Foundation

// MARK: - IPC Message Types

/// Messages received from hook scripts via Unix domain socket
public enum IPCMessage: Equatable {
    case register(RegisterMessage)
    case notification(NotificationMessage)
    case clear(ClearMessage)
    case deregister(DeregisterMessage)
}

// MARK: - Register Message

public struct RegisterMessage: Codable, Equatable {
    public let sessionId: String
    public let tmux: String
    public let cwd: String
    public let source: String
    public let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case tmux
        case cwd
        case source
        case timestamp
    }

    public init(sessionId: String, tmux: String, cwd: String, source: String, timestamp: Int) {
        self.sessionId = sessionId
        self.tmux = tmux
        self.cwd = cwd
        self.source = source
        self.timestamp = timestamp
    }
}

// MARK: - Notification Message

public struct NotificationMessage: Codable, Equatable {
    public let sessionId: String
    public let tmux: String
    public let message: String
    public let notificationType: String
    public let lastMessage: String?
    public let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case tmux
        case message
        case notificationType = "notification_type"
        case lastMessage = "last_message"
        case timestamp
    }

    public init(
        sessionId: String,
        tmux: String,
        message: String,
        notificationType: String,
        lastMessage: String?,
        timestamp: Int
    ) {
        self.sessionId = sessionId
        self.tmux = tmux
        self.message = message
        self.notificationType = notificationType
        self.lastMessage = lastMessage
        self.timestamp = timestamp
    }
}

// MARK: - Clear Message

public struct ClearMessage: Codable, Equatable {
    public let sessionId: String
    public let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case timestamp
    }

    public init(sessionId: String, timestamp: Int) {
        self.sessionId = sessionId
        self.timestamp = timestamp
    }
}

// MARK: - Deregister Message

public struct DeregisterMessage: Codable, Equatable {
    public let sessionId: String
    public let reason: String
    public let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case reason
        case timestamp
    }

    public init(sessionId: String, reason: String, timestamp: Int) {
        self.sessionId = sessionId
        self.reason = reason
        self.timestamp = timestamp
    }
}

// MARK: - Message Parsing

public struct IPCMessageParser {
    public init() {}

    public func parse(_ data: Data) throws -> IPCMessage {
        // First, decode to get the type field
        struct TypeWrapper: Codable {
            let type: String
        }

        let wrapper = try JSONDecoder().decode(TypeWrapper.self, from: data)

        switch wrapper.type {
        case "register":
            let message = try JSONDecoder().decode(RegisterMessage.self, from: data)
            return .register(message)
        case "notification":
            let message = try JSONDecoder().decode(NotificationMessage.self, from: data)
            return .notification(message)
        case "clear":
            let message = try JSONDecoder().decode(ClearMessage.self, from: data)
            return .clear(message)
        case "deregister":
            let message = try JSONDecoder().decode(DeregisterMessage.self, from: data)
            return .deregister(message)
        default:
            throw IPCError.unknownMessageType(wrapper.type)
        }
    }
}

// MARK: - Errors

public enum IPCError: Error, Equatable {
    case unknownMessageType(String)
    case invalidJSON
    case socketError(String)
}
