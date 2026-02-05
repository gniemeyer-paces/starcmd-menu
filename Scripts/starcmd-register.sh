#!/bin/bash
# StarCmd: SessionStart hook - registers session with menu bar app

# Read JSON input from stdin
INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd')
SOURCE=$(echo "$INPUT" | jq -r '.source')

# Detect tmux context - prefer env var set by wrapper to avoid race condition
if [ -n "$STARCMD_TMUX_CONTEXT" ]; then
  TMUX_CONTEXT="$STARCMD_TMUX_CONTEXT"
elif [ -n "$TMUX" ]; then
  TMUX_SESSION=$(/opt/homebrew/bin/tmux display-message -p '#S')
  TMUX_WINDOW=$(/opt/homebrew/bin/tmux display-message -p '#W')
  TMUX_WINDOW_ID=$(/opt/homebrew/bin/tmux display-message -p '#{window_id}')
  TMUX_PANE_ID=$(/opt/homebrew/bin/tmux display-message -p '#{pane_id}')
  TMUX_CONTEXT="${TMUX_SESSION}:${TMUX_WINDOW}:${TMUX_WINDOW_ID}:${TMUX_PANE_ID}"
else
  TMUX_CONTEXT="standalone"
fi

OUTPUT="{
  \"type\": \"register\",
  \"session_id\": \"$SESSION_ID\",
  \"tmux\": \"$TMUX_CONTEXT\",
  \"cwd\": \"$CWD\",
  \"source\": \"$SOURCE\",
  \"timestamp\": $(date +%s)
}"

# Debug log: structured single-line entry for easy parsing
echo "{\"ts\":\"$(date -Iseconds)\",\"hook\":\"register\",\"session_id\":\"$SESSION_ID\",\"tmux\":\"$TMUX_CONTEXT\",\"cwd\":\"$CWD\"}" >> /tmp/starcmd-debug.log

echo "$OUTPUT" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
