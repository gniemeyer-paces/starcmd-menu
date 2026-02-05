#!/bin/bash
# StarCmd: SessionEnd hook - removes session from menu bar app

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
REASON=$(echo "$INPUT" | jq -r '.reason')

# Debug log: structured single-line entry for easy parsing
echo "{\"ts\":\"$(date -Iseconds)\",\"hook\":\"deregister\",\"session_id\":\"$SESSION_ID\",\"reason\":\"$REASON\"}" >> /tmp/starcmd-debug.log

echo "{
  \"type\": \"deregister\",
  \"session_id\": \"$SESSION_ID\",
  \"reason\": \"$REASON\",
  \"timestamp\": $(date +%s)
}" | nc -U /tmp/starcmd.sock 2>/dev/null

exit 0
