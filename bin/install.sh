#!/bin/zsh
# One-time installer. Safe to re-run — it skips anything already done, and
# tells you in plain words what to do next if something is missing.

set -uo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
say()  { echo "→ $*"; }
fail() { echo "❌ $*"; exit 1; }

echo "== Daily Ticket Summary — installer =="
echo "Working in: $DIR"
echo

# ---- 1. OS check ----
[[ "$(uname)" == "Darwin" ]] || fail "This only works on a Mac (it uses macOS's launchd scheduler)."
ok "macOS detected"

# ---- 2. Required tools ----
MISSING=0
check_tool() {
  local name=$1 cmd=$2 hint=$3
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$name found"
  else
    warn "$name not found. Install it with: $hint"
    MISSING=1
  fi
}
check_tool "Claude Code"                claude "curl -fsSL https://claude.ai/install.sh | sh"
check_tool "uv (needed for Jira)"       uvx    "brew install uv"
check_tool "Node.js (needed for Backlog & Slack)" npx "brew install node"

if [[ $MISSING -eq 1 ]]; then
  echo
  fail "Install the missing tool(s) above (open a new Terminal window afterwards), then run bin/install.sh again."
fi
echo

# ---- 3. config.env ----
if [[ ! -f "$DIR/config.env" ]]; then
  cp "$DIR/config.example.env" "$DIR/config.env"
  chmod 600 "$DIR/config.env"
  echo
  warn "Created config.env from the template — it's still empty."
  echo "   Open it with:  open -e \"$DIR/config.env\""
  echo "   Follow docs/getting-your-tokens.md to fill in every value."
  echo "   Then run bin/install.sh again."
  exit 0
fi
chmod 600 "$DIR/config.env"

set -a
source "$DIR/config.env"
set +a

REQUIRED=(SLACK_USER_ID JIRA_EMAIL JIRA_API_TOKEN BACKLOG_API_KEY SLACK_BOT_TOKEN SLACK_TEAM_ID JIRA_URL BACKLOG_DOMAIN)
MISSING_FIELDS=()
for var in "${REQUIRED[@]}"; do
  [[ -n "${(P)var:-}" ]] || MISSING_FIELDS+=("$var")
done
if [[ ${#MISSING_FIELDS[@]} -gt 0 ]]; then
  warn "config.env is missing a value for: ${(j:, :)MISSING_FIELDS}"
  echo "   See docs/getting-your-tokens.md, fill those in, then run bin/install.sh again."
  exit 1
fi
ok "config.env looks complete"
echo

# ---- 4. Register the three MCP servers Claude needs ----
register_mcp() {
  local name=$1; shift
  if claude mcp list 2>/dev/null | grep -q "^${name}:"; then
    ok "MCP server '$name' already registered"
  else
    say "Registering MCP server '$name'..."
    if claude mcp add "$name" -s user "$@" >/tmp/mcp-add-$name.log 2>&1; then
      ok "'$name' registered"
    else
      cat "/tmp/mcp-add-$name.log"
      fail "Could not register '$name' (see the error above — usually a typo in config.env)."
    fi
  fi
}
register_mcp new-jira -e JIRA_URL="$JIRA_URL" -e JIRA_USERNAME="$JIRA_EMAIL" -e JIRA_API_TOKEN="$JIRA_API_TOKEN" \
  -- uvx mcp-atlassian
register_mcp backlog -e BACKLOG_DOMAIN="$BACKLOG_DOMAIN" -e BACKLOG_API_KEY="$BACKLOG_API_KEY" \
  -- npx -y backlog-mcp-server
register_mcp slack -e SLACK_BOT_TOKEN="$SLACK_BOT_TOKEN" -e SLACK_TEAM_ID="$SLACK_TEAM_ID" \
  -- npx -y @modelcontextprotocol/server-slack
echo

# ---- 5. backlog-exclude.txt ----
[[ -f "$DIR/backlog-exclude.txt" ]] || cp "$DIR/backlog-exclude.example.txt" "$DIR/backlog-exclude.txt"
ok "backlog-exclude.txt ready (empty = watch every Backlog project)"

# ---- 6. Make scripts executable ----
chmod +x "$DIR"/bin/*.sh
ok "Scripts made executable"

# ---- 7. Shell shortcut: `ticket-summary` ----
ALIAS_LINE="alias ticket-summary='zsh \"$DIR/bin/run.sh\" --now'"
if ! grep -qF "$ALIAS_LINE" ~/.zshrc 2>/dev/null; then
  { echo ""; echo "# Added by daily-ticket-summary installer"; echo "$ALIAS_LINE"; } >> ~/.zshrc
  ok "Added the 'ticket-summary' shortcut to ~/.zshrc"
else
  ok "'ticket-summary' shortcut already in ~/.zshrc"
fi

# ---- 8. Scheduled job (launchd) ----
SAFE_USER=$(whoami | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')
JOB_LABEL="com.${SAFE_USER}.daily-ticket-summary"
PLIST="$HOME/Library/LaunchAgents/${JOB_LABEL}.plist"

sed \
  -e "s|{{JOB_LABEL}}|$JOB_LABEL|g" \
  -e "s|{{REPO_DIR}}|$DIR|g" \
  -e "s|{{HOME}}|$HOME|g" \
  "$DIR/templates/launchd.plist.template" > "$PLIST"

plutil -lint "$PLIST" >/dev/null || fail "Generated plist is invalid — please report this as a bug."
ok "Wrote $PLIST"

launchctl bootout "gui/$(id -u)/$JOB_LABEL" >/dev/null 2>&1 || true
if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  ok "Scheduled job loaded — checks every 3 min, ${WINDOW_START_HOUR}:00-${WINDOW_END_HOUR}:00, weekdays only"
else
  fail "Could not load the scheduled job. Try manually:  launchctl bootstrap gui/\$(id -u) \"$PLIST\""
fi

echo
echo "== Install complete =="
echo "Open a NEW terminal window (so the 'ticket-summary' shortcut is available), then run:"
echo "   ticket-summary"
echo "to get your first summary right now."
echo
echo "Anytime later, run bin/doctor.sh to check that everything is still healthy."
