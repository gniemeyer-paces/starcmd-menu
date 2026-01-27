import Foundation

/// Unix domain socket server for receiving IPC messages from hook scripts
public actor SocketServer {
    private let path: String
    private let messageHandler: @Sendable (IPCMessage) -> Void
    private let parser = IPCMessageParser()

    private var serverSocket: Int32 = -1
    private var isRunning = false
    private var acceptTask: Task<Void, Never>?

    public init(path: String, messageHandler: @escaping @Sendable (IPCMessage) -> Void = { _ in }) {
        self.path = path
        self.messageHandler = messageHandler
    }

    public func start() throws {
        // Remove existing socket file if present
        try? FileManager.default.removeItem(atPath: path)

        // Create socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw IPCError.socketError("Failed to create socket: \(errno)")
        }

        // Set non-blocking mode
        let flags = fcntl(serverSocket, F_GETFL)
        _ = fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)

        // Set up the address
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy path to sun_path
        let pathBytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
            pathBytes.withUnsafeBufferPointer { pathBuffer in
                let dest = UnsafeMutableRawPointer(sunPath)
                    .assumingMemoryBound(to: CChar.self)
                for i in 0..<min(pathBuffer.count, 104) {
                    dest[i] = pathBuffer[i]
                }
            }
        }

        // Bind
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverSocket)
            throw IPCError.socketError("Failed to bind socket: \(errno)")
        }

        // Listen
        guard listen(serverSocket, 5) == 0 else {
            close(serverSocket)
            try? FileManager.default.removeItem(atPath: path)
            throw IPCError.socketError("Failed to listen on socket: \(errno)")
        }

        isRunning = true

        // Start accepting connections in background
        let socket = serverSocket
        let handler = messageHandler
        let parserCopy = parser
        let pathCopy = path

        acceptTask = Task.detached { [weak self] in
            await Self.acceptLoop(
                serverSocket: socket,
                path: pathCopy,
                parser: parserCopy,
                messageHandler: handler,
                isRunning: { await self?.isRunning ?? false }
            )
        }
    }

    public func stop() {
        isRunning = false
        acceptTask?.cancel()

        if serverSocket >= 0 {
            // Shutdown to wake up any blocked accept
            shutdown(serverSocket, SHUT_RDWR)
            close(serverSocket)
            serverSocket = -1
        }

        try? FileManager.default.removeItem(atPath: path)
    }

    private static func acceptLoop(
        serverSocket: Int32,
        path: String,
        parser: IPCMessageParser,
        messageHandler: @escaping @Sendable (IPCMessage) -> Void,
        isRunning: @escaping () async -> Bool
    ) async {
        while await isRunning() && !Task.isCancelled {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }

            if clientSocket < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // No connection available, sleep briefly and retry
                    try? await Task.sleep(for: .milliseconds(10))
                    continue
                }
                // Server socket was closed or error
                break
            }

            // Handle client synchronously (messages are small)
            Self.handleClient(socket: clientSocket, parser: parser, messageHandler: messageHandler)
        }
    }

    private static func handleClient(
        socket clientSocket: Int32,
        parser: IPCMessageParser,
        messageHandler: @escaping @Sendable (IPCMessage) -> Void
    ) {
        defer { close(clientSocket) }

        var buffer = [UInt8](repeating: 0, count: 8192)
        var data = Data()

        while true {
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            if bytesRead <= 0 {
                break
            }
            data.append(contentsOf: buffer[0..<bytesRead])
        }

        guard !data.isEmpty else { return }

        do {
            let message = try parser.parse(data)
            messageHandler(message)
        } catch {
            // Log error but don't crash - invalid messages are silently ignored
            print("StarCmd: Failed to parse message: \(error)")
        }
    }
}
