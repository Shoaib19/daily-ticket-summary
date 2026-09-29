#!/bin/zsh
# Removes the scheduled job and the 'ticket-summary' shortcut.
# Does NOT delete config.env or your registered MCP servers — remove those
# yourself if you're sure you don't need them elsewhere (see the note at the end).

DIR="$(cd "$(dirname "$0")/.." && pwd)"
SAFE_USER=$(whoami | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')
JOB_LABEL="com.${SAFE_USER}.daily-ticket-summary"
PLIST="$HOME/Library/LaunchAgents/${JOB_LABEL}.plist"

echo "This removes the scheduled job and the 'ticket-summary' shortcut."
echo "It does NOT delete config.env or your MCP server registrations."
read "REPLY?Continue? [y/N] "
[[ "$REPLY" == "y" || "$REPLY" == "Y" ]] || { echo "Cancelled."; exit 0; }

if launchctl bootout "gui/$(id -u)/$JOB_LABEL" 2>/dev/null; then
  echo "✅ Scheduled job unloaded"
else
  echo "ℹ️  Scheduled job was not loaded"
fi
[[ -f "$PLIST" ]] && rm "$PLIST" && echo "✅ Removed $PLIST"

if [[ -f ~/.zshrc ]]; then
  sed -i '' "\|daily-ticket-summary/bin/run.sh|d" ~/.zshrc
  sed -i '' "/# Added by daily-ticket-summary installer/d" ~/.zshrc
  echo "✅ Removed the 'ticket-summary' shortcut from ~/.zshrc"
fi

echo
echo "Done. To remove everything completely:"
echo "  1. Delete this folder."
echo "  2. Only if you don't use these MCP servers anywhere else:"
echo "       claude mcp remove new-jira"
echo "       claude mcp remove backlog"
echo "       claude mcp remove slack"
