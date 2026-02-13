#!/bin/bash
# StarCmd: Notification hook - forwards notifications to menu bar app

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
MESSAGE=$(echo "$INPUT" | jq -r '.message')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

# Detect tmux context - prefer env var set by wrapper
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

# For idle prompts, extract the last assistant message from transcript
LAST_MESSAGE=""
if [ "$NOTIFICATION_TYPE" = "idle_prompt" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  LAST_MESSAGE=$(tail -100 "$TRANSCRIPT_PATH" | \
    jq -s '[.[] | select(.type == "assistant")] | last | .message.content[0].text // empty' 2>/dev/null)
fi

# Use printf to avoid trailing newlines, handle empty strings properly
if [ -z "$LAST_MESSAGE" ]; then
  LAST_MESSAGE_JSON='""'
else
  LAST_MESSAGE_JSON=$(printf '%s' "$LAST_MESSAGE" | jq -Rs .)
fi

MESSAGE_JSON=$(printf '%s' "$MESSAGE" | jq -Rs .)

OUTPUT="{
  \"type\": \"notification\",
  \"session_id\": \"$SESSION_ID\",
  \"tmux\": \"$TMUX_CONTEXT\",
  \"message\": $MESSAGE_JSON,
  \"notification_type\": \"$NOTIFICATION_TYPE\",
  \"last_message\": $LAST_MESSAGE_JSON,
  \"timestamp\": $(date +%s)
}"

# Debug log: structured single-line entry for easy parsing
echo "{\"ts\":\"$(date -Iseconds)\",\"hook\":\"notify\",\"session_id\":\"$SESSION_ID\",\"tmux\":\"$TMUX_CONTEXT\",\"notification_type\":\"$NOTIFICATION_TYPE\"}" >> /tmp/starcmd-debug.log

echo "$OUTPUT" | nc -U /tmp/starcmd.sock 2>/dev/null

# Flash tmux status bar on notification (only for non-active panes)
if [ -n "$TMUX" ]; then
  TMX=/opt/homebrew/bin/tmux
  # Extract notifying pane from tmux context (session:window:windowId:paneId)
  NOTIFY_PANE=$(echo "$TMUX_CONTEXT" | awk -F: '{print $NF}')
  ACTIVE_PANE=$($TMX display-message -p '#{pane_id}' 2>/dev/null)
  [ "$NOTIFY_PANE" = "$ACTIVE_PANE" ] && exit 0
  case "$NOTIFICATION_TYPE" in
    tool_error|permission_prompt|elicitation_dialog)
      FLASH_BG="red" ;;
    *)
      FLASH_BG="colour208" ;;  # orange
  esac
  # Signal the glow loop — blocked (red) supersedes idle (orange)
  CURRENT_GLOW=$($TMX show-environment -g STARCMD_GLOW 2>/dev/null | cut -d= -f2)
  if [ "$CURRENT_GLOW" != "red" ] || [ "$FLASH_BG" = "red" ]; then
    $TMX set-environment -g STARCMD_GLOW "$FLASH_BG" 2>/dev/null
  fi
  # Only start the loop if one isn't already running
  GLOW_PID=$($TMX show-environment -g STARCMD_GLOW_PID 2>/dev/null | cut -d= -f2)
  if [ -z "$GLOW_PID" ] || ! kill -0 "$GLOW_PID" 2>/dev/null; then
    (
      ORIG_STYLE=$($TMX show-options -gv status-style 2>/dev/null)
      while true; do
        GLOW=$($TMX show-environment -g STARCMD_GLOW 2>/dev/null | cut -d= -f2)
        [ -z "$GLOW" ] && break
        # Auto-dismiss red glow when no sessions are blocked
        if [ "$GLOW" = "red" ]; then
          BLOCKED=$(echo '{"type":"list","timestamp":0}' | nc -U /tmp/starcmd.sock 2>/dev/null | jq '[.[] | select(.status=="blocked")] | length' 2>/dev/null)
          if [ "${BLOCKED:-0}" -eq 0 ]; then
            $TMX set-environment -gu STARCMD_GLOW 2>/dev/null
            break
          fi
        fi
        for c in colour64 colour100 colour136 colour172 "$GLOW"; do
          $TMX set-option -g status-style "bg=$c,fg=black" 2>/dev/null
          sleep 0.08
        done
        for c in colour172 colour136 colour100 colour64; do
          $TMX set-option -g status-style "bg=$c,fg=black" 2>/dev/null
          sleep 0.08
        done
        $TMX set-option -g status-style "$ORIG_STYLE" 2>/dev/null
        sleep 0.3
      done
    ) &
    $TMX set-environment -g STARCMD_GLOW_PID "$!" 2>/dev/null
  fi
fi

exit 0
