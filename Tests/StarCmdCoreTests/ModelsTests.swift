import Testing
@testable import StarCmdCore

@Suite("Models Tests")
struct ModelsTests {

    // MARK: - TmuxContext Tests

    @Test("Parse valid tmux context string")
    func tmuxContextParsing() {
        let context = TmuxContext(from: "dev:editor:%8")
        #expect(context != nil)
        #expect(context?.session == "dev")
        #expect(context?.window == "editor")
        #expect(context?.paneId == "%8")
    }

    @Test("TmuxContext display name format")
    func tmuxContextDisplayName() {
        let context = TmuxContext(session: "main", window: "code", paneId: "%12")
        #expect(context.displayName == "main:code:%12")
    }

    @Test("Parse invalid tmux context strings")
    func tmuxContextParsingInvalid() {
        #expect(TmuxContext(from: "invalid") == nil)
        #expect(TmuxContext(from: "dev:editor") == nil)
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
        let context = TmuxContext(session: "dev", window: "editor", paneId: "%5")
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
