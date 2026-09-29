#!/bin/zsh
# Looks up Backlog user IDs by name, so you can fill in BACKLOG_WATCH_USER_IDS
# in config.env. Requires bin/install.sh to have finished successfully first
# (it needs the 'backlog' MCP server already registered).
#
# Usage:
#   bin/find-backlog-ids.sh "Faisal" "Pravin" "Makoto"

[[ $# -ge 1 ]] || { echo "Usage: $0 \"Name1\" \"Name2\" ..."; exit 1; }
NAMES="$*"

CLAUDE=$(command -v claude || echo "$HOME/.local/bin/claude")

echo "Searching Backlog for: $NAMES  (this can take a minute across many projects)"
echo

"$CLAUDE" -p "Search Backlog for users whose name contains any of: $NAMES
(case-insensitive, partial matches OK, names may be in English or Japanese).
Use mcp__backlog__get_project_list to list all projects, then
mcp__backlog__get_project_users for each project (skip a project silently if that call
errors), and mcp__backlog__get_users as a fallback. Print ONLY a table with columns
Name | Backlog User ID | Email, one row per distinct person found, no duplicate rows,
no other commentary before or after the table." \
  --allowedTools "mcp__backlog__get_project_list mcp__backlog__get_project_users mcp__backlog__get_users"

echo
echo "Copy the IDs above (comma-separated) into config.env as BACKLOG_WATCH_USER_IDS,"
echo "and the matching names into BACKLOG_WATCH_NAMES."
