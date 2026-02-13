#!/bin/bash
# StarCmd tmux integration — session picker, nav stack, status bar
# Usage: starcmd-tmux.sh [pick|back|forward|status|show]

TMX=/opt/homebrew/bin/tmux
SOCK=/tmp/starcmd.sock
ACTION="${1:-show}"

get_stack() { $TMX show-environment -g "STARCMD_$1" 2>/dev/null | cut -d= -f2; }
set_stack() { $TMX set-environment -g "STARCMD_$1" "$2"; }

case "$ACTION" in
  pick)
    # Dismiss glow notification
    $TMX set-environment -gu STARCMD_GLOW 2>/dev/null
    # fzf session picker — meant to run inside display-popup
    LINES=$(echo '{"type":"list","timestamp":0}' | nc -U "$SOCK" 2>/dev/null | jq -r '
      sort_by(-.lastActivityAt) | .[] |
      (if .status == "blocked" then "⚠ BLOCKED"
       elif .status == "idle" then "⏸ IDLE   "
       else "✓ WORKING" end) as $icon |
      "\(.paneId)|\($icon)|\(.tmux)|\(.cwd)"' 2>/dev/null)

    [ -z "$LINES" ] && { echo "No active sessions"; sleep 1; exit 0; }

    SELECTED=$(echo "$LINES" | \
      awk -F'|' '{printf "%-6s  %s  %-30s  %s\n", $1, $2, $3, $4}' | \
      fzf --ansi --header="Select a Claude session" --no-border --no-sort --layout=reverse)

    [ -z "$SELECTED" ] && exit 0

    PANE_ID=$(echo "$SELECTED" | awk '{print $1}')
    $TMX switch-client -t "$PANE_ID"
    sleep 0.1
    ;;

  back)
    BACK=$(get_stack BACK)
    [ -z "$BACK" ] && exit 0
    DEST=$(echo "$BACK" | cut -d, -f1)
    REST=$(echo "$BACK" | cut -d, -f2- -s)
    CURRENT=$($TMX display-message -p '#{pane_id}')
    FWD=$(get_stack FWD)
    if [ -n "$FWD" ]; then
      set_stack FWD "${CURRENT},${FWD}"
    else
      set_stack FWD "$CURRENT"
    fi
    set_stack BACK "$REST"
    $TMX switch-client -t "$DEST"
    ;;

  forward)
    FWD=$(get_stack FWD)
    [ -z "$FWD" ] && exit 0
    DEST=$(echo "$FWD" | cut -d, -f1)
    REST=$(echo "$FWD" | cut -d, -f2- -s)
    CURRENT=$($TMX display-message -p '#{pane_id}')
    BACK=$(get_stack BACK)
    if [ -n "$BACK" ]; then
      set_stack BACK "${CURRENT},${BACK}"
    else
      set_stack BACK "$CURRENT"
    fi
    set_stack FWD "$REST"
    $TMX switch-client -t "$DEST"
    ;;

  status)
    # Status bar segment — outputs tmux format strings with color
    RESPONSE=$(echo '{"type":"list","timestamp":0}' | nc -U "$SOCK" 2>/dev/null | jq '.' 2>/dev/null)
    [ -z "$RESPONSE" ] && exit 0

    BLOCKED=$(echo "$RESPONSE" | jq '[.[] | select(.status=="blocked")] | length')
    IDLE=$(echo "$RESPONSE" | jq '[.[] | select(.status=="idle")] | length')
    TOTAL=$(echo "$RESPONSE" | jq 'length')
    WORKING=$((TOTAL - BLOCKED - IDLE))

    [ "$TOTAL" -eq 0 ] && exit 0

    PARTS=""
    [ "$BLOCKED" -gt 0 ] && PARTS="${PARTS}#[fg=black,bg=red,bold] ⚠ ${BLOCKED} #[default,bg=green]"
    [ "$IDLE" -gt 0 ] && PARTS="${PARTS}#[fg=black,bg=yellow,bold] ⏸ ${IDLE} #[default,bg=green]"
    [ "$WORKING" -gt 0 ] && PARTS="${PARTS}#[fg=black,bg=green] ✓ ${WORKING} #[default,bg=green]"

    echo "${PARTS}"
    ;;

  show)
    echo "Back:    $(get_stack BACK)"
    echo "Forward: $(get_stack FWD)"
    ;;

  *)
    echo "Usage: starcmd-tmux.sh [pick|back|forward|status|show]"
    exit 1
    ;;
esac
