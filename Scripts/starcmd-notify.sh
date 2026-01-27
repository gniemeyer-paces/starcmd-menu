#!/bin/bash
# StarCmd: Notification hook - forwards notifications to menu bar app

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
}" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
