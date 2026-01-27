# StarCmd

A macOS menu bar application for managing Claude Code session notifications across tmux panes.

## Overview

StarCmd provides a centralized view of all active Claude Code sessions running in tmux, displaying their status and notifications. Click any session to jump directly to that tmux pane in Ghostty.

```
┌─────────────────────────────────────────┐
│  [✓] SC                                 │  ← Menu bar
├─────────────────────────────────────────┤
│  ● dev:editor:%8      Working           │
│  ● api:main:%12       Blocked      2m   │
│    › "Claude needs permission to..."    │
│  ● test:runner:%15    Idle         5m   │
│    › "What auth method would you..."    │
│─────────────────────────────────────────│
│  ← Back    Forward →                    │
│─────────────────────────────────────────│
│  Quit StarCmd                           │
└─────────────────────────────────────────┘
```

## Status Indicators

| Color  | Menu Bar Icon              | Meaning                          |
|--------|----------------------------|----------------------------------|
| Green  | `✓` (checkmark.circle)     | All sessions working normally    |
| Orange | `…` (ellipsis.circle)      | Session idle, waiting for input  |
| Red    | `⚠` (exclamationmark.triangle) | Session blocked, needs action |

Priority: Red > Orange > Green

## Requirements

- macOS 13+
- [tmux](https://github.com/tmux/tmux) (installed via Homebrew)
- [Ghostty](https://ghostty.org/) terminal
- [jq](https://jqlang.github.io/jq/) for JSON parsing in hooks
- [Claude Code](https://claude.ai/code) CLI

## Installation

```bash
# Clone the repo
git clone https://github.com/yourusername/starcmd.git
cd starcmd

# Run the install script
./install.sh
```

This will:
1. Build the release binary
2. Install to `/usr/local/bin/starcmd`
3. Install hook scripts to `~/bin/`
4. Set up LaunchAgent for auto-start

## Hook Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/bin/starcmd-register.sh" }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/bin/starcmd-deregister.sh" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/bin/starcmd-notify.sh" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/bin/starcmd-clear.sh" }] }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/bin/starcmd-clear.sh" }] }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual username.

### Hook Summary

| Hook | When It Fires | StarCmd Action |
|------|---------------|----------------|
| `SessionStart` | Claude Code session begins | Register session (green) |
| `Notification` | Permission prompt or idle (60s+) | Update status (red/orange) |
| `UserPromptSubmit` | User submits a prompt | Clear to green |
| `PostToolUse` | Tool completes | Clear to green |
| `SessionEnd` | Session terminates | Remove session |

## Shell Wrapper (Recommended)

Add this to your `.zshrc` to prevent a race condition where switching panes before Claude registers could capture the wrong pane:

```zsh
claude() {
    if [[ -n "$TMUX" ]]; then
        export STARCMD_TMUX_CONTEXT="$(/opt/homebrew/bin/tmux display-message -p '#S:#W:#{window_id}:#{pane_id}')"
    fi
    command claude "$@"
}
```

This captures the tmux context before Claude starts, ensuring the correct pane is registered.

## Usage

### Navigation
- **Click session name** → Focus that tmux pane in Ghostty
- **Click notification preview** → Expand/collapse full message
- **Back/Forward buttons** → Navigate between previously focused panes

### Managing the App

```bash
# Stop StarCmd
launchctl unload ~/Library/LaunchAgents/com.starcmd.agent.plist

# Start StarCmd
launchctl load ~/Library/LaunchAgents/com.starcmd.agent.plist

# Reload after rebuilding
launchctl unload ~/Library/LaunchAgents/com.starcmd.agent.plist 2>/dev/null
sudo cp .build/release/StarCmd /usr/local/bin/starcmd
launchctl load ~/Library/LaunchAgents/com.starcmd.agent.plist
```

### Logs

```bash
# View StarCmd logs
tail -f /tmp/starcmd.log

# View hook debug logs
tail -f /tmp/starcmd-debug.log
```

## Development

```bash
# Build debug
swift build

# Run debug build
.build/debug/StarCmd

# Run tests
swift test

# Build release
swift build -c release
```

## Architecture

- **Menu Bar App**: Swift + SwiftUI (`MenuBarExtra`)
- **IPC**: Unix domain socket at `/tmp/starcmd.sock`
- **Hook Scripts**: Bash + jq
- **Focus**: tmux `switch-client` + `select-window` + `select-pane`, then `open -a Ghostty`

## Limitations

- Requires tmux - standalone terminal sessions are not tracked
- Requires Ghostty - focus action opens Ghostty specifically
- Single instance only - second instance will exit with error
