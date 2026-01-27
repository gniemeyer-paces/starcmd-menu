#!/bin/bash
# StarCmd: UserPromptSubmit hook - clears blocked/idle status

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

echo "{
  \"type\": \"clear\",
  \"session_id\": \"$SESSION_ID\",
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
