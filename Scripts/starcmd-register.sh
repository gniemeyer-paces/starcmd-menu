#!/bin/bash
# StarCmd: SessionStart hook - registers session with menu bar app

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
}" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
