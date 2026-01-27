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
        let target = session.tmuxContext

        // Switch client to target session, then select pane by absolute ID
        // The pane ID (e.g., %8) uniquely identifies the pane across all sessions
        let script = """
        /opt/homebrew/bin/tmux switch-client -t '\(target.session)' && \
        /opt/homebrew/bin/tmux select-pane -t '\(target.paneId)' && \
        open -a Ghostty
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

        do {
            try process.run()
        } catch {
            print("StarCmd: Focus failed: \(error)")
        }
    }
}
