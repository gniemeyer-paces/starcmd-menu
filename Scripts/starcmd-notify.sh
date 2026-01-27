#!/bin/bash
# StarCmd: Notification hook - forwards notifications to menu bar app

INPUT=$(cat)

# Debug logging
echo "[$(date)] starcmd-notify.sh called" >> /tmp/starcmd-debug.log
echo "$INPUT" >> /tmp/starcmd-debug.log

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
MESSAGE=$(echo "$INPUT" | jq -r '.message')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

# Detect tmux context (in case of reconnection)
if [ -n "$TMUX" ]; then
  TMUX_SESSION=$(/opt/homebrew/bin/tmux display-message -p '#S')
  TMUX_WINDOW=$(/opt/homebrew/bin/tmux display-message -p '#W')
  TMUX_PANE_ID=$(/opt/homebrew/bin/tmux display-message -p '#{pane_id}')
  TMUX_CONTEXT="${TMUX_SESSION}:${TMUX_WINDOW}:${TMUX_PANE_ID}"
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

echo "Sending: $OUTPUT" >> /tmp/starcmd-debug.log
echo "$OUTPUT" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
