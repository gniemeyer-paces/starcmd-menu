import Testing
import Foundation
@testable import StarCmdCore

@Suite("Integration Tests")
struct IntegrationTests {

    @Test("Full IPC flow: register -> notify -> clear -> deregister")
    func fullIPCFlow() async throws {
        let socketPath = "/tmp/starcmd-integration-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let sessionManager = SessionManager()

        // Start socket server with session manager
        let server = SocketServer(path: socketPath) { message in
            Task { await sessionManager.handleMessage(message) }
        }
        try await server.start()

        // Give server time to start
        try await Task.sleep(for: .milliseconds(100))

        // 1. Register a session
        try await sendMessage(to: socketPath, json: """
        {"type":"register","session_id":"integration-test","tmux":"test:0:1","cwd":"/tmp/test","source":"startup","timestamp":\(Int(Date().timeIntervalSince1970))}
        """)
        try await Task.sleep(for: .milliseconds(100))

        var sessions = await sessionManager.sessions
        #expect(sessions.count == 1)
        #expect(sessions["integration-test"]?.status == .working)

        // 2. Send notification (blocked)
        try await sendMessage(to: socketPath, json: """
        {"type":"notification","session_id":"integration-test","tmux":"test:0:1","message":"Permission needed","notification_type":"permission_prompt","last_message":"","timestamp":\(Int(Date().timeIntervalSince1970))}
        """)
        try await Task.sleep(for: .milliseconds(100))

        sessions = await sessionManager.sessions
        #expect(sessions["integration-test"]?.status == .blocked)

        // 3. Clear (user submitted prompt)
        try await sendMessage(to: socketPath, json: """
        {"type":"clear","session_id":"integration-test","timestamp":\(Int(Date().timeIntervalSince1970))}
        """)
        try await Task.sleep(for: .milliseconds(100))

        sessions = await sessionManager.sessions
        #expect(sessions["integration-test"]?.status == .working)

        // 4. Send notification (idle)
        try await sendMessage(to: socketPath, json: """
        {"type":"notification","session_id":"integration-test","tmux":"test:0:1","message":"Waiting","notification_type":"idle_prompt","last_message":"What do you want?","timestamp":\(Int(Date().timeIntervalSince1970))}
        """)
        try await Task.sleep(for: .milliseconds(100))

        sessions = await sessionManager.sessions
        #expect(sessions["integration-test"]?.status == .idle)
        #expect(sessions["integration-test"]?.lastNotification?.lastMessage == "What do you want?")

        // 5. Deregister
        try await sendMessage(to: socketPath, json: """
        {"type":"deregister","session_id":"integration-test","reason":"exit","timestamp":\(Int(Date().timeIntervalSince1970))}
        """)
        try await Task.sleep(for: .milliseconds(100))

        sessions = await sessionManager.sessions
        #expect(sessions.count == 0)

        await server.stop()
    }

    @Test("Hook script format compatibility")
    func hookScriptFormat() async throws {
        let socketPath = "/tmp/starcmd-hooktest-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let collector = MessageCollector()
        let server = SocketServer(path: socketPath) { message in
            Task { await collector.append(message) }
        }
        try await server.start()
        try await Task.sleep(for: .milliseconds(100))

        // Test the exact format our hook scripts produce
        let scriptDir = ProcessInfo.processInfo.environment["PWD"] ?? "."
        let registerScript = "\(scriptDir)/Scripts/starcmd-register.sh"

        // Simulate hook script input
        let hookInput = """
        {"session_id":"hook-test-123","cwd":"/Users/test/project","source":"startup"}
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", """
            export TMUX=""
            echo '\(hookInput)' | SOCKET_PATH="\(socketPath)" bash -c '
                INPUT=$(cat)
                SESSION_ID=$(echo "$INPUT" | jq -r ".session_id")
                CWD=$(echo "$INPUT" | jq -r ".cwd")
                SOURCE=$(echo "$INPUT" | jq -r ".source")
                TMUX_CONTEXT="standalone"
                echo "{
                  \\"type\\": \\"register\\",
                  \\"session_id\\": \\"$SESSION_ID\\",
                  \\"tmux\\": \\"$TMUX_CONTEXT\\",
                  \\"cwd\\": \\"$CWD\\",
                  \\"source\\": \\"$SOURCE\\",
                  \\"timestamp\\": $(date +%s)
                }" | nc -U "\(socketPath)"
            '
        """]

        try process.run()
        process.waitUntilExit()

        try await Task.sleep(for: .milliseconds(200))
        await server.stop()

        // The message IS received by the socket server (it accepts all valid JSON)
        // but SessionManager will ignore registrations with invalid tmux contexts like "standalone"
        let count = await collector.count()
        #expect(count == 1) // Message received, but will be ignored by SessionManager
    }

    // MARK: - Helpers

    private func sendMessage(to socketPath: String, json: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-U", socketPath]

        let pipe = Pipe()
        process.standardInput = pipe

        try process.run()
        pipe.fileHandleForWriting.write(json.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
    }
}

/// Reuse MessageCollector from SocketServerTests
extension MessageCollector {
    func getMessages() -> [IPCMessage] {
        messages
    }
}
