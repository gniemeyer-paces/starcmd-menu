import Testing
import Foundation
@testable import StarCmdCore

@Suite("Session Manager Tests")
struct SessionManagerTests {

    @Test("Register creates new session")
    func registerSession() async {
        let manager = SessionManager()

        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            cwd: "/Users/test/project",
            source: "startup",
            timestamp: 1706400000
        )))

        let sessions = await manager.sessions
        #expect(sessions.count == 1)
        #expect(sessions["abc123"]?.tmuxContext.displayName == "dev:editor:%5")
        #expect(sessions["abc123"]?.status == .working)
    }

    @Test("Notification updates session status to blocked")
    func notificationBlocked() async {
        let manager = SessionManager()

        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            cwd: "/tmp",
            source: "startup",
            timestamp: 1706400000
        )))

        await manager.handleMessage(.notification(NotificationMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            message: "Claude needs permission",
            notificationType: "permission_prompt",
            lastMessage: nil,
            timestamp: 1706400100
        )))

        let sessions = await manager.sessions
        #expect(sessions["abc123"]?.status == .blocked)
        #expect(sessions["abc123"]?.lastNotification?.message == "Claude needs permission")
    }

    @Test("Notification updates session status to idle")
    func notificationIdle() async {
        let manager = SessionManager()

        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            cwd: "/tmp",
            source: "startup",
            timestamp: 1706400000
        )))

        await manager.handleMessage(.notification(NotificationMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            message: "Waiting for input",
            notificationType: "idle_prompt",
            lastMessage: "What auth method?",
            timestamp: 1706400100
        )))

        let sessions = await manager.sessions
        #expect(sessions["abc123"]?.status == .idle)
        #expect(sessions["abc123"]?.lastNotification?.lastMessage == "What auth method?")
    }

    @Test("Clear resets session status to working")
    func clearResetsStatus() async {
        let manager = SessionManager()

        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            cwd: "/tmp",
            source: "startup",
            timestamp: 1706400000
        )))

        await manager.handleMessage(.notification(NotificationMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            message: "Permission needed",
            notificationType: "permission_prompt",
            lastMessage: nil,
            timestamp: 1706400100
        )))

        #expect(await manager.sessions["abc123"]?.status == .blocked)

        await manager.handleMessage(.clear(ClearMessage(
            sessionId: "abc123",
            timestamp: 1706400150
        )))

        #expect(await manager.sessions["abc123"]?.status == .working)
    }

    @Test("Deregister removes session")
    func deregisterRemovesSession() async {
        let manager = SessionManager()

        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "abc123",
            tmux: "dev:editor:@2:%5",
            cwd: "/tmp",
            source: "startup",
            timestamp: 1706400000
        )))

        #expect(await manager.sessions.count == 1)

        await manager.handleMessage(.deregister(DeregisterMessage(
            sessionId: "abc123",
            reason: "exit",
            timestamp: 1706400200
        )))

        #expect(await manager.sessions.count == 0)
    }

    @Test("Aggregate status returns worst status")
    func aggregateStatus() async {
        let manager = SessionManager()

        // No sessions = working (green)
        #expect(await manager.aggregateStatus == .working)

        // One working session
        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "s1", tmux: "dev:editor:@2:%5", cwd: "/tmp", source: "startup", timestamp: 1
        )))
        #expect(await manager.aggregateStatus == .working)

        // Add idle session - should be idle (orange)
        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "s2", tmux: "dev:editor:@3:%6", cwd: "/tmp", source: "startup", timestamp: 2
        )))
        await manager.handleMessage(.notification(NotificationMessage(
            sessionId: "s2", tmux: "dev:editor:@3:%6", message: "Idle",
            notificationType: "idle_prompt", lastMessage: nil, timestamp: 3
        )))
        #expect(await manager.aggregateStatus == .idle)

        // Add blocked session - should be blocked (red)
        await manager.handleMessage(.register(RegisterMessage(
            sessionId: "s3", tmux: "dev:editor:@4:%7", cwd: "/tmp", source: "startup", timestamp: 4
        )))
        await manager.handleMessage(.notification(NotificationMessage(
            sessionId: "s3", tmux: "dev:editor:@4:%7", message: "Permission",
            notificationType: "permission_prompt", lastMessage: nil, timestamp: 5
        )))
        #expect(await manager.aggregateStatus == .blocked)
    }
}
