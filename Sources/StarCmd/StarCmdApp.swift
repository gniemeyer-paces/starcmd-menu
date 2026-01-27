import SwiftUI
import StarCmdCore

@main
struct StarCmdApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            HStack(spacing: 4) {
                StatusIcon(status: appState.aggregateStatus)
                Text("SC")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [ClaudeSession] = []
    @Published var aggregateStatus: SessionStatus = .working

    private let sessionManager = SessionManager()
    private var socketServer: SocketServer?

    init() {
        // Start with hardcoded test data for development
        #if DEBUG
        loadTestData()
        #endif

        // Start socket server
        Task {
            await startSocketServer()
        }
    }

    private func startSocketServer() async {
        let manager = sessionManager

        socketServer = SocketServer(path: "/tmp/starcmd.sock") { [weak self] message in
            Task { @MainActor in
                await manager.handleMessage(message)
                await self?.refreshFromManager()
            }
        }

        do {
            try await socketServer?.start()
            print("StarCmd: Socket server started at /tmp/starcmd.sock")
        } catch {
            print("StarCmd: Failed to start socket server: \(error)")
        }
    }

    private func refreshFromManager() async {
        sessions = await sessionManager.sortedSessions
        aggregateStatus = await sessionManager.aggregateStatus
    }

    func focusSession(_ session: ClaudeSession) {
        let tmux = "/opt/homebrew/bin/tmux"
        let target = session.tmuxContext

        // Activate Ghostty
        if let ghosttyURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
            NSWorkspace.shared.openApplication(at: ghosttyURL, configuration: NSWorkspace.OpenConfiguration())
        }

        // Select tmux window and pane
        let selectWindow = Process()
        selectWindow.executableURL = URL(fileURLWithPath: tmux)
        selectWindow.arguments = ["select-window", "-t", "\(target.session):\(target.window)"]
        try? selectWindow.run()
        selectWindow.waitUntilExit()

        let selectPane = Process()
        selectPane.executableURL = URL(fileURLWithPath: tmux)
        selectPane.arguments = ["select-pane", "-t", "\(target.session):\(target.window).\(target.pane)"]
        try? selectPane.run()
        selectPane.waitUntilExit()
    }

    // MARK: - Test Data

    #if DEBUG
    private func loadTestData() {
        sessions = [
            ClaudeSession(
                id: "test1",
                tmuxContext: TmuxContext(session: "dev", window: 0, pane: 1),
                cwd: "/Users/test/project",
                status: .working
            ),
            ClaudeSession(
                id: "test2",
                tmuxContext: TmuxContext(session: "api", window: 0, pane: 0),
                cwd: "/Users/test/api",
                status: .blocked,
                lastNotification: SessionNotification(
                    message: "Claude needs permission to use Bash",
                    type: .permissionPrompt,
                    lastMessage: nil,
                    timestamp: Date()
                )
            ),
            ClaudeSession(
                id: "test3",
                tmuxContext: TmuxContext(session: "test", window: 1, pane: 2),
                cwd: "/Users/test/tests",
                status: .idle,
                lastNotification: SessionNotification(
                    message: "Claude is waiting for input",
                    type: .idlePrompt,
                    lastMessage: "What authentication method would you like to use?",
                    timestamp: Date().addingTimeInterval(-120)
                )
            )
        ]
        aggregateStatus = .blocked
    }
    #endif
}
