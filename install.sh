#!/bin/bash
set -e

echo "Building StarCmd..."
swift build -c release

echo "Installing binary to /usr/local/bin/starcmd..."
sudo cp .build/release/StarCmd /usr/local/bin/starcmd

echo "Installing hook scripts to ~/bin/..."
mkdir -p ~/bin
cp Scripts/*.sh ~/bin/
chmod +x ~/bin/starcmd-*.sh

echo "Installing LaunchAgent..."
cp com.starcmd.agent.plist ~/Library/LaunchAgents/

echo "Loading LaunchAgent..."
launchctl unload ~/Library/LaunchAgents/com.starcmd.agent.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.starcmd.agent.plist

echo ""
echo "StarCmd installed successfully!"
echo ""
echo "Make sure your ~/.claude/settings.json has the hooks configured."
echo "See PLAN.md for the hook configuration."
echo ""
echo "Tmux integration: add the following to your ~/.tmux.conf:"
echo '  bind-key C display-popup -E -h "60%" -w "80%" "bash ~/bin/starcmd-tmux.sh pick"'
echo '  bind-key B run-shell "bash ~/bin/starcmd-tmux.sh back"'
echo '  bind-key F run-shell "bash ~/bin/starcmd-tmux.sh forward"'
echo '  set -g status-right "#(bash ~/bin/starcmd-tmux.sh status) ..."'
echo '  set -g status-right-length 100'
echo '  set -g status-interval 2'
