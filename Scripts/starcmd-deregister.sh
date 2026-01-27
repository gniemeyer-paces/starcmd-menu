#!/bin/bash
# StarCmd: SessionEnd hook - removes session from menu bar app

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
REASON=$(echo "$INPUT" | jq -r '.reason')

echo "{
  \"type\": \"deregister\",
  \"session_id\": \"$SESSION_ID\",
  \"reason\": \"$REASON\",
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
