import Testing
import Foundation
@testable import StarCmdCore

/// Thread-safe message collector for tests
actor MessageCollector {
    var messages: [IPCMessage] = []

    func append(_ message: IPCMessage) {
        messages.append(message)
    }

    func count() -> Int {
        messages.count
    }

    func first() -> IPCMessage? {
        messages.first
    }
}

@Suite("Socket Server Tests")
struct SocketServerTests {

    @Test("Socket server creates socket file")
    func socketCreation() async throws {
        let socketPath = "/tmp/starcmd-test-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let server = SocketServer(path: socketPath)
        try await server.start()

        #expect(FileManager.default.fileExists(atPath: socketPath))

        await server.stop()

        // Give filesystem time to sync
        try await Task.sleep(for: .milliseconds(50))
        #expect(!FileManager.default.fileExists(atPath: socketPath))
    }

    @Test("Socket server receives messages")
    func receiveMessage() async throws {
        let socketPath = "/tmp/starcmd-test-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let collector = MessageCollector()
        let server = SocketServer(path: socketPath) { message in
            Task { await collector.append(message) }
        }
        try await server.start()

        // Send a test message using nc
        let json = """
        {"type":"register","session_id":"test123","tmux":"dev:editor:%5","cwd":"/tmp","source":"startup","timestamp":1234567890}
        """

        // Use Process to send via nc
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-U", socketPath]

        let pipe = Pipe()
        process.standardInput = pipe

        try process.run()
        pipe.fileHandleForWriting.write(json.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        // Give the server a moment to process
        try await Task.sleep(for: .milliseconds(200))

        await server.stop()

        let count = await collector.count()
        #expect(count == 1)

        if let first = await collector.first(), case .register(let msg) = first {
            #expect(msg.sessionId == "test123")
        } else {
            Issue.record("Expected register message")
        }
    }

    @Test("Socket server handles multiple connections")
    func multipleConnections() async throws {
        let socketPath = "/tmp/starcmd-test-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let collector = MessageCollector()
        let server = SocketServer(path: socketPath) { message in
            Task { await collector.append(message) }
        }
        try await server.start()

        // Send multiple messages
        for i in 0..<3 {
            let json = """
            {"type":"register","session_id":"test\(i)","tmux":"dev:editor:%\(i)","cwd":"/tmp","source":"startup","timestamp":1234567890}
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            process.arguments = ["-U", socketPath]

            let pipe = Pipe()
            process.standardInput = pipe

            try process.run()
            pipe.fileHandleForWriting.write(json.data(using: .utf8)!)
            pipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            // Small delay between connections
            try await Task.sleep(for: .milliseconds(50))
        }

        try await Task.sleep(for: .milliseconds(200))
        await server.stop()

        let count = await collector.count()
        #expect(count == 3)
    }
}
