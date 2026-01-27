import Testing
@testable import StarCmdCore

@Suite("IPC Message Tests")
struct IPCMessageTests {
    let parser = IPCMessageParser()

    // MARK: - Register Message Tests

    @Test("Parse register message")
    func parseRegisterMessage() throws {
        let json = """
        {
          "type": "register",
          "session_id": "abc123",
          "tmux": "dev:0:1",
          "cwd": "/Users/user/project",
          "source": "startup",
          "timestamp": 1706400000
        }
        """

        let message = try parser.parse(json.data(using: .utf8)!)

        guard case .register(let reg) = message else {
            Issue.record("Expected register message")
            return
        }

        #expect(reg.sessionId == "abc123")
        #expect(reg.tmux == "dev:0:1")
        #expect(reg.cwd == "/Users/user/project")
        #expect(reg.source == "startup")
        #expect(reg.timestamp == 1706400000)
    }

    // MARK: - Notification Message Tests

    @Test("Parse notification message")
    func parseNotificationMessage() throws {
        let json = """
        {
          "type": "notification",
          "session_id": "abc123",
          "tmux": "dev:0:1",
          "message": "Claude needs permission to use Bash",
          "notification_type": "permission_prompt",
          "last_message": "",
          "timestamp": 1706400100
        }
        """

        let message = try parser.parse(json.data(using: .utf8)!)

        guard case .notification(let notif) = message else {
            Issue.record("Expected notification message")
            return
        }

        #expect(notif.sessionId == "abc123")
        #expect(notif.notificationType == "permission_prompt")
        #expect(notif.message == "Claude needs permission to use Bash")
    }

    @Test("Parse notification with last assistant message")
    func parseNotificationWithLastMessage() throws {
        let json = """
        {
          "type": "notification",
          "session_id": "abc123",
          "tmux": "dev:0:1",
          "message": "Claude is waiting for input",
          "notification_type": "idle_prompt",
          "last_message": "What authentication method would you like to use?",
          "timestamp": 1706400100
        }
        """

        let message = try parser.parse(json.data(using: .utf8)!)

        guard case .notification(let notif) = message else {
            Issue.record("Expected notification message")
            return
        }

        #expect(notif.notificationType == "idle_prompt")
        #expect(notif.lastMessage == "What authentication method would you like to use?")
    }

    // MARK: - Clear Message Tests

    @Test("Parse clear message")
    func parseClearMessage() throws {
        let json = """
        {
          "type": "clear",
          "session_id": "abc123",
          "timestamp": 1706400150
        }
        """

        let message = try parser.parse(json.data(using: .utf8)!)

        guard case .clear(let clear) = message else {
            Issue.record("Expected clear message")
            return
        }

        #expect(clear.sessionId == "abc123")
        #expect(clear.timestamp == 1706400150)
    }

    // MARK: - Deregister Message Tests

    @Test("Parse deregister message")
    func parseDeregisterMessage() throws {
        let json = """
        {
          "type": "deregister",
          "session_id": "abc123",
          "reason": "exit",
          "timestamp": 1706400200
        }
        """

        let message = try parser.parse(json.data(using: .utf8)!)

        guard case .deregister(let dereg) = message else {
            Issue.record("Expected deregister message")
            return
        }

        #expect(dereg.sessionId == "abc123")
        #expect(dereg.reason == "exit")
    }

    // MARK: - Error Cases

    @Test("Unknown message type throws error")
    func parseUnknownType() {
        let json = """
        {
          "type": "unknown",
          "data": "test"
        }
        """

        #expect(throws: IPCError.self) {
            try parser.parse(json.data(using: .utf8)!)
        }
    }

    @Test("Invalid JSON throws error")
    func parseInvalidJSON() {
        let json = "not valid json"

        #expect(throws: (any Error).self) {
            try parser.parse(json.data(using: .utf8)!)
        }
    }
}
