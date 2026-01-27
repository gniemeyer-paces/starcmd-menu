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
