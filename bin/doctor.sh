#!/bin/zsh
# Checks every piece of the setup and explains, in plain words, what's wrong
# and (roughly) how to fix it. Safe to run anytime.

DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok()  { echo "✅ $*"; PASS=$((PASS+1)); }
bad() { echo "❌ $*"; FAIL=$((FAIL+1)); }

echo "== Daily Ticket Summary — doctor =="
echo

if [[ "$(uname)" == "Darwin" ]]; then ok "Running on macOS"; else bad "Not macOS — this only works on a Mac"; fi

for pair in "claude:Claude Code" "uvx:uv (needed for Jira)" "npx:Node.js (needed for Backlog & Slack)"; do
  cmd="${pair%%:*}"; name="${pair#*:}"
  if command -v "$cmd" >/dev/null 2>&1; then ok "$name is installed"; else bad "$name is missing"; fi
done

if [[ -f "$DIR/config.env" ]]; then
  ok "config.env exists"
  set -a; source "$DIR/config.env"; set +a
  for var in SLACK_USER_ID JIRA_EMAIL JIRA_API_TOKEN BACKLOG_API_KEY SLACK_BOT_TOKEN SLACK_TEAM_ID; do
    if [[ -n "${(P)var:-}" ]]; then ok "$var is set"; else bad "$var is empty in config.env"; fi
  done
else
  bad "config.env is missing — copy config.example.env to config.env and fill it in (see bin/install.sh)"
fi

for name in new-jira backlog slack; do
  if claude mcp list 2>/dev/null | grep -q "^${name}:"; then
    ok "MCP server '$name' is registered"
  else
    bad "MCP server '$name' is not registered — run bin/install.sh"
  fi
done

SAFE_USER=$(whoami | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')
JOB_LABEL="com.${SAFE_USER}.daily-ticket-summary"
if launchctl print "gui/$(id -u)/$JOB_LABEL" >/dev/null 2>&1; then
  ok "Scheduled job is loaded ($JOB_LABEL)"
else
  bad "Scheduled job is not loaded — run bin/install.sh"
fi

if grep -q "daily-ticket-summary/bin/run.sh" ~/.zshrc 2>/dev/null; then
  ok "'ticket-summary' shortcut is in ~/.zshrc"
else
  bad "'ticket-summary' shortcut is missing — run bin/install.sh"
fi

if curl -sI --max-time 5 https://slack.com >/dev/null; then ok "Internet is reachable"; else bad "Can't reach the internet right now"; fi

echo
echo "$PASS checks passed, $FAIL failed."
if [[ $FAIL -eq 0 ]]; then
  echo "Everything looks good. Try:  ticket-summary"
else
  echo "Fix the ❌ items above (docs/troubleshooting.md may help), then run bin/doctor.sh again."
fi
