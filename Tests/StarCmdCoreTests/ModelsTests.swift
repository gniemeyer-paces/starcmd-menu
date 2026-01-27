import Testing
@testable import StarCmdCore

@Suite("Models Tests")
struct ModelsTests {

    // MARK: - TmuxContext Tests

    @Test("Parse valid tmux context string")
    func tmuxContextParsing() {
        let context = TmuxContext(from: "dev:0:1")
        #expect(context != nil)
        #expect(context?.session == "dev")
        #expect(context?.window == 0)
        #expect(context?.pane == 1)
    }

    @Test("TmuxContext display name format")
    func tmuxContextDisplayName() {
        let context = TmuxContext(session: "main", window: 2, pane: 3)
        #expect(context.displayName == "main:2:3")
    }

    @Test("Parse invalid tmux context strings")
    func tmuxContextParsingInvalid() {
        #expect(TmuxContext(from: "invalid") == nil)
        #expect(TmuxContext(from: "dev:notanumber:1") == nil)
        #expect(TmuxContext(from: "dev:0") == nil)
        #expect(TmuxContext(from: "standalone") == nil)
    }

    // MARK: - NotificationType Tests

    @Test("Notification types map to correct status")
    func notificationTypeStatus() {
        #expect(NotificationType.permissionPrompt.resultingStatus == .blocked)
        #expect(NotificationType.elicitationDialog.resultingStatus == .blocked)
        #expect(NotificationType.idlePrompt.resultingStatus == .idle)
    }

    // MARK: - ClaudeSession Tests

    @Test("Create session with defaults")
    func claudeSessionCreation() {
        let context = TmuxContext(session: "dev", window: 0, pane: 1)
        let session = ClaudeSession(
            id: "abc123",
            tmuxContext: context,
            cwd: "/Users/test/project"
        )

        #expect(session.id == "abc123")
        #expect(session.tmuxContext == context)
        #expect(session.cwd == "/Users/test/project")
        #expect(session.status == .working)
        #expect(session.lastNotification == nil)
    }
}
