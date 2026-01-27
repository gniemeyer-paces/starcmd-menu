# StarCmd: Claude Code Notification Manager

A macOS menu bar application for managing Claude Code session notifications across tmux panes.

## Overview

StarCmd provides a centralized view of all active Claude Code sessions running in tmux, displaying their status and notifications. It uses Claude Code hooks to track session lifecycle and notification events.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     macOS Menu Bar App                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ● starcmd                                               │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  ● dev:0:1    Working...                    [green]      │   │
│  │  ● api:0:0    Blocked: Permission needed   [red]        │   │
│  │  ◐ test:1:2   Idle (2m)                    [yellow]     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
           ▲           ▲           ▲           ▲
           │           │           │           │
    ┌──────┴───┐ ┌─────┴────┐ ┌────┴─────┐ ┌───┴────────┐
    │SessionStart│ │Notification│ │SessionEnd│ │UserPrompt  │
    │   Hook    │ │   Hook    │ │   Hook   │ │ Submit Hook│
    └──────┬───┘ └─────┬────┘ └────┬─────┘ └───┬────────┘
           │           │           │           │
           └───────────┴───────────┴───────────┘
                              │
                     Unix Domain Socket
                     /tmp/starcmd.sock
```

## Components

### 1. Menu Bar Application (Swift/SwiftUI)

**Core Features:**
- Menu bar icon with aggregate status indicator
- Dropdown list of active Claude Code sessions
- Per-session status: green (working), yellow (idle), red (blocked)
- Expandable notification details
- Click-to-focus: activate Ghostty and select tmux pane

**Status Indicators:**
| Icon | Color  | Meaning                                      |
|------|--------|----------------------------------------------|
| ●    | Green  | Session active, working normally             |
| ◐    | Yellow | Needs attention (idle 60s+, waiting for input) |
| ●    | Red    | Blocked (permission prompt, requires action) |

**Visual Effects:**
- Red/Yellow states trigger a subtle glow or pulse animation on the menu bar icon
- Uses `NSStatusBarButton` with `CABasicAnimation` for pulsing effect
- Glow fades in/out on a 2-second cycle to draw attention without being annoying

**Menu Structure:**
```
[●] StarCmd
├── dev:0:1 ● Working
│   └── (expand) Last: "Reading file src/main.rs"
├── api:0:0 ● Blocked
│   └── (expand) "Claude needs permission to use Bash"
│   └── [Focus in Ghostty]
├── test:1:2 ◐ Idle (2m)
│   └── (expand) "What authentication method would you like?"
│   └── [Focus in Ghostty]
├── ─────────────
├── Settings...
└── Quit
```

### 2. Hook Scripts

Four shell scripts communicate with the menu bar app via Unix domain socket.

#### `starcmd-register.sh` (SessionStart Hook)
```bash
#!/bin/bash
# Called on SessionStart - registers session with menu bar app

# Read JSON input from stdin
INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd')
SOURCE=$(echo "$INPUT" | jq -r '.source')

# Detect tmux context
if [ -n "$TMUX" ]; then
  TMUX_SESSION=$(/opt/homebrew/bin/tmux display-message -p '#S')
  TMUX_WINDOW=$(/opt/homebrew/bin/tmux display-message -p '#I')
  TMUX_PANE=$(/opt/homebrew/bin/tmux display-message -p '#P')
  TMUX_CONTEXT="${TMUX_SESSION}:${TMUX_WINDOW}:${TMUX_PANE}"
else
  TMUX_CONTEXT="standalone"
fi

# Send registration to menu bar app
echo "{
  \"type\": \"register\",
  \"session_id\": \"$SESSION_ID\",
  \"tmux\": \"$TMUX_CONTEXT\",
  \"cwd\": \"$CWD\",
  \"source\": \"$SOURCE\",
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock

exit 0
```

#### `starcmd-notify.sh` (Notification Hook)
```bash
#!/bin/bash
# Called on Notification events

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
MESSAGE=$(echo "$INPUT" | jq -r '.message')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

# Detect tmux context (in case of reconnection)
if [ -n "$TMUX" ]; then
  TMUX_CONTEXT="$(/opt/homebrew/bin/tmux display-message -p '#S:#I:#P')"
else
  TMUX_CONTEXT="standalone"
fi

# For idle prompts, extract the last assistant message from transcript
LAST_MESSAGE=""
if [ "$NOTIFICATION_TYPE" = "idle_prompt" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  LAST_MESSAGE=$(tail -100 "$TRANSCRIPT_PATH" | \
    jq -s '[.[] | select(.type == "assistant")] | last | .message.content[0].text // empty' 2>/dev/null | \
    head -c 300)
fi

# Send notification to menu bar app
echo "{
  \"type\": \"notification\",
  \"session_id\": \"$SESSION_ID\",
  \"tmux\": \"$TMUX_CONTEXT\",
  \"message\": $(echo "$MESSAGE" | jq -Rs .),
  \"notification_type\": \"$NOTIFICATION_TYPE\",
  \"last_message\": $(echo "$LAST_MESSAGE" | jq -Rs .),
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock

exit 0
```

#### `starcmd-deregister.sh` (SessionEnd Hook)
```bash
#!/bin/bash
# Called on SessionEnd - removes session from menu bar app

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
REASON=$(echo "$INPUT" | jq -r '.reason')

echo "{
  \"type\": \"deregister\",
  \"session_id\": \"$SESSION_ID\",
  \"reason\": \"$REASON\",
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock

exit 0
```

#### `starcmd-clear.sh` (UserPromptSubmit Hook)
```bash
#!/bin/bash
# Called on UserPromptSubmit - clears blocked/idle status

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

echo "{
  \"type\": \"clear\",
  \"session_id\": \"$SESSION_ID\",
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock

exit 0
```

### 3. Claude Code Hook Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/starcmd-register.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/starcmd-deregister.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/starcmd-notify.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/starcmd-clear.sh"
          }
        ]
      }
    ]
  }
}
```

## Data Model

### Session State
```swift
struct ClaudeSession: Identifiable {
    let id: String                    // session_id from Claude Code
    var tmuxContext: TmuxContext      // session:window:pane
    var cwd: String                   // working directory
    var status: SessionStatus         // .working, .idle, .blocked
    var lastNotification: Notification?
    var registeredAt: Date
    var lastActivityAt: Date
}

struct TmuxContext {
    let session: String
    let window: Int
    let pane: Int

    var displayName: String {
        "\(session):\(window):\(pane)"
    }
}

enum SessionStatus {
    case working              // Green - active, working normally
    case idle                 // Yellow - idle_prompt, waiting for input
    case blocked              // Red - permission_prompt, requires action
}

struct Notification {
    let message: String
    let type: NotificationType
    let lastMessage: String?       // Last assistant message (for idle_prompt)
    let timestamp: Date
}

enum NotificationType: String {
    case permissionPrompt = "permission_prompt"   // → blocked (red)
    case idlePrompt = "idle_prompt"               // → idle (yellow)
    case elicitationDialog = "elicitation_dialog" // → blocked (red)
}
```

## IPC Protocol

Communication via Unix domain socket at `/tmp/starcmd.sock`.

### Messages (Hook → App)

**Register:**
```json
{
  "type": "register",
  "session_id": "abc123",
  "tmux": "dev:0:1",
  "cwd": "/Users/user/project",
  "source": "startup",
  "timestamp": 1706400000
}
```

**Notification:**
```json
{
  "type": "notification",
  "session_id": "abc123",
  "tmux": "dev:0:1",
  "message": "Claude needs permission to use Bash",
  "notification_type": "permission_prompt",
  "last_message": "",
  "timestamp": 1706400100
}
```

**Notification (idle with last assistant message):**
```json
{
  "type": "notification",
  "session_id": "abc123",
  "tmux": "dev:0:1",
  "message": "Claude is waiting for input",
  "notification_type": "idle_prompt",
  "last_message": "What authentication method would you like to use?",
  "timestamp": 1706400100
}
```

**Deregister:**
```json
{
  "type": "deregister",
  "session_id": "abc123",
  "reason": "exit",
  "timestamp": 1706400200
}
```

**Clear (on prompt submit):**
```json
{
  "type": "clear",
  "session_id": "abc123",
  "timestamp": 1706400150
}
```

## Key Features

### 1. Aggregate Status Icon
- **Green**: All sessions working normally
- **Yellow**: At least one session idle (waiting for input)
- **Red**: At least one session blocked (permission needed)

Priority: Red > Yellow > Green

### 2. Click-to-Focus (Ghostty + tmux)
When clicking a session or "Focus in Ghostty" button:

```swift
func focusSession(_ session: ClaudeSession) {
    // 1. Activate Ghostty
    NSWorkspace.shared.launchApplication("Ghostty")
    // or: open -a Ghostty

    // 2. Select the tmux window and pane
    let tmux = "/opt/homebrew/bin/tmux"
    let target = session.tmuxContext

    Process.run(tmux, arguments: [
        "select-window", "-t", "\(target.session):\(target.window)"
    ])
    Process.run(tmux, arguments: [
        "select-pane", "-t", "\(target.session):\(target.window).\(target.pane)"
    ])
}
```

This brings Ghostty to the foreground and switches to the correct tmux pane.

### 3. Notification Expansion
Click on a session to expand and see:
- Full notification message
- Notification type
- Time since notification
- Working directory
- Focus button

### 4. Session Timeout
Sessions without activity for 24 hours are automatically pruned (handles cases where SessionEnd hook fails to fire).

## Technology Stack

| Component        | Technology           |
|------------------|----------------------|
| Menu Bar App     | Swift + SwiftUI      |
| IPC              | Unix Domain Socket   |
| Hook Scripts     | Bash + jq            |
| Build            | Xcode / swift build  |
| Distribution     | Homebrew tap (optional) |

## File Structure

```
starcmd/
├── StarCmd/                    # macOS app
│   ├── StarCmdApp.swift        # App entry point
│   ├── MenuBarView.swift       # Menu bar UI
│   ├── SessionManager.swift    # Session state management
│   ├── SocketServer.swift      # Unix socket listener
│   ├── TmuxController.swift    # tmux + Ghostty focus
│   └── Models/
│       ├── ClaudeSession.swift
│       └── Notification.swift
├── Scripts/                    # Hook scripts
│   ├── starcmd-register.sh
│   ├── starcmd-notify.sh
│   ├── starcmd-deregister.sh
│   └── starcmd-clear.sh
├── Package.swift               # Swift package manifest
├── Makefile                    # Build & install targets
└── README.md
```

## Installation Plan

1. Build the Swift menu bar app
2. Install hook scripts to `/usr/local/bin/`
3. Configure Claude Code hooks in `~/.claude/settings.json`
4. Launch StarCmd (add to Login Items for persistence)

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Unix domain socket server in Swift
- [ ] Basic menu bar app with hardcoded test data
- [ ] Hook scripts that write to socket

### Phase 2: Session Management
- [ ] Session registration/deregistration
- [ ] Real-time status updates
- [ ] Notification storage and display

### Phase 3: UI Polish
- [ ] Expandable notification details
- [ ] Click-to-focus tmux pane
- [ ] Aggregate status icon logic
- [ ] Settings panel (socket path, timeout config)

### Phase 4: Reliability
- [ ] Handle socket reconnection
- [ ] Session timeout/cleanup
- [ ] Error handling and logging
- [ ] LaunchAgent for auto-start

## Design Decisions

1. **No sounds** - Visual indicators only. Icon glow/pulse effect for red/yellow states.
2. **No history** - Only track current notification per session.
3. **tmux required** - No graceful handling for non-tmux sessions.
4. **Clear on prompt submit** - Status resets to green when user submits a prompt (via `UserPromptSubmit` hook).

## References

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [SwiftUI Menu Bar Apps](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Unix Domain Sockets in Swift](https://developer.apple.com/documentation/foundation/urlsessionstreamtask)
