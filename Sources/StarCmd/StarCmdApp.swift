import SwiftUI
import StarCmdCore

// Change this to try different icon styles:
// .solid, .stacked, .stackedFading, .cascade, .dual
let currentIconStyle: IconStyle = .dual

@main
struct StarCmdApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            MenuBarIcon(status: appState.aggregateStatus)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIcon: View {
    let status: SessionStatus

    var body: some View {
        Image(nsImage: combinedIcon)
    }

    private var combinedIcon: NSImage {
        let claudeIcon = IconGenerator.generateMenuBarIcon(style: currentIconStyle)
        let statusIcon = NSImage(systemSymbolName: statusSymbol, accessibilityDescription: nil)!

        let spacing: CGFloat = 0
        let statusSize: CGFloat = 18
        let totalWidth = statusSize + spacing + claudeIcon.size.width
        let height = max(claudeIcon.size.height, statusSize)

        let result = NSImage(size: NSSize(width: totalWidth, height: height))
        result.lockFocus()

        // Draw status icon on left
        let config = NSImage.SymbolConfiguration(pointSize: statusSize, weight: .medium)
        if let configuredStatus = statusIcon.withSymbolConfiguration(config) {
            configuredStatus.draw(in: NSRect(x: 0,
                                              y: (height - statusSize) / 2,
                                              width: statusSize, height: statusSize))
        }

        // Draw Claude icon on right
        claudeIcon.draw(in: NSRect(x: statusSize + spacing, y: (height - claudeIcon.size.height) / 2,
                                    width: claudeIcon.size.width, height: claudeIcon.size.height))

        result.unlockFocus()
        result.isTemplate = true
        return result
    }

    private var statusSymbol: String {
        switch status {
        case .working: return "checkmark.circle"
        case .idle: return "ellipsis.circle"
        case .blocked: return "exclamationmark.triangle"
        }
    }
}

// MARK: - App State

struct PaneLocation: Equatable {
    let session: String
    let windowId: String
    let paneId: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [ClaudeSession] = []
    @Published var aggregateStatus: SessionStatus = .working
    @Published var backStack: [PaneLocation] = []
    @Published var forwardStack: [PaneLocation] = []

    private let sessionManager = SessionManager()
    private var socketServer: SocketServer?

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

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
            print("StarCmd: \(error.localizedDescription)")
            // Exit if we can't start (e.g., another instance is running)
            NSApplication.shared.terminate(nil)
        }
    }

    private func refreshFromManager() async {
        sessions = await sessionManager.sortedSessions
        aggregateStatus = await sessionManager.aggregateStatus
    }

    func focusSession(_ session: ClaudeSession) {
        // Capture current pane before switching
        if let current = getCurrentPane() {
            backStack.append(current)
        }
        // Clear forward stack on new navigation
        forwardStack.removeAll()

        let target = session.tmuxContext
        let script = """
        /opt/homebrew/bin/tmux switch-client -t '\(target.session)' && \
        /opt/homebrew/bin/tmux select-window -t '\(target.windowId)' && \
        /opt/homebrew/bin/tmux select-pane -t '\(target.paneId)' && \
        open -a Ghostty
        """
        runScript(script)
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        // Push current to forward stack
        if let current = getCurrentPane() {
            forwardStack.append(current)
        }
        focusPane(session: previous.session, windowId: previous.windowId, paneId: previous.paneId)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        // Push current to back stack
        if let current = getCurrentPane() {
            backStack.append(current)
        }
        focusPane(session: next.session, windowId: next.windowId, paneId: next.paneId)
    }

    private func runScript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        do {
            try process.run()
        } catch {
            print("StarCmd: Focus failed: \(error)")
        }
    }

    private func getCurrentPane() -> PaneLocation? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tmux")
        process.arguments = ["display-message", "-p", "#{session_name}\t#{window_id}\t#{pane_id}"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return nil }

            let parts = output.split(separator: "\t")
            guard parts.count == 3 else { return nil }

            return PaneLocation(session: String(parts[0]), windowId: String(parts[1]), paneId: String(parts[2]))
        } catch {
            return nil
        }
    }

    private func focusPane(session: String, windowId: String, paneId: String) {
        let script = """
        /opt/homebrew/bin/tmux switch-client -t '\(session)' && \
        /opt/homebrew/bin/tmux select-window -t '\(windowId)' && \
        /opt/homebrew/bin/tmux select-pane -t '\(paneId)' && \
        open -a Ghostty
        """
        runScript(script)
    }
}
