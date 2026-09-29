#!/bin/zsh
# Posts a Jira + Backlog ticket summary to your Slack DM.
#   auto (launchd, every 3 min): once per weekday, within your configured window,
#                                 only when you're at the unlocked laptop.
#   manual (run.sh --now):       immediately, no checks. For special days/times.
#
# You should not normally run this file directly — use `bin/install.sh` once,
# then the `ticket-summary` shortcut it adds for manual runs.

set -uo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$DIR/state"
LOGFILE="$HOME/Library/Logs/daily-ticket-summary.log"
mkdir -p "$STATE" "$(dirname "$LOGFILE")"
log() { echo "$(date '+%F %T') $*"; }

# ---- load config ----
if [[ ! -f "$DIR/config.env" ]]; then
  echo "Missing $DIR/config.env — copy config.example.env to config.env and fill it in."
  echo "See README.md (step 3) and docs/getting-your-tokens.md."
  exit 1
fi
set -a
source "$DIR/config.env"
set +a

: "${SLACK_USER_ID:?Set SLACK_USER_ID in config.env}"
: "${JIRA_URL:?Set JIRA_URL in config.env}"
: "${BACKLOG_DOMAIN:?Set BACKLOG_DOMAIN in config.env}"
: "${WINDOW_START_HOUR:=9}"
: "${WINDOW_END_HOUR:=12}"

CLAUDE=$(command -v claude || echo "$HOME/.local/bin/claude")

MODE=auto
[[ "${1:-}" == "--now" ]] && MODE=manual

if [[ $MODE == auto ]]; then
  [[ $(date +%u) -le 5 ]] || exit 0                                          # weekdays only (1=Mon…7=Sun)
  HOUR=$(( 10#$(date +%H) ))                                                 # 10# forces base-10 (avoids "08"/"09" octal errors)
  (( HOUR >= WINDOW_START_HOUR && HOUR < WINDOW_END_HOUR )) || exit 0        # inside the configured window
  [[ "$(cat "$STATE/last-date" 2>/dev/null)" != "$(date +%F)" ]] || exit 0   # only once per day
  ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes' && exit 0     # screen locked → not at the laptop yet
else
  exec > >(tee -a "$LOGFILE") 2>&1                                           # manual: show output AND log it
fi

if ! curl -sI --max-time 5 https://slack.com >/dev/null; then
  [[ $MODE == manual ]] && log "No network reachable yet — try again in a moment."
  exit 0
fi

LAST_AT="$(cat "$STATE/last-at" 2>/dev/null || echo 'never')"
EXCLUDE_FILE="$DIR/backlog-exclude.txt"
[[ -f "$EXCLUDE_FILE" ]] || EXCLUDE_FILE="$DIR/backlog-exclude.example.txt"
EXCLUDE="$(grep -vE '^[[:space:]]*(#|$)' "$EXCLUDE_FILE" 2>/dev/null | tr '\n' ' ')"

# ---- fill in the prompt template (| as sed delimiter since URLs contain /) ----
PROMPT="$(sed \
  -e "s|{{SLACK_USER_ID}}|$SLACK_USER_ID|g" \
  -e "s|{{JIRA_URL}}|$JIRA_URL|g" \
  -e "s|{{BACKLOG_DOMAIN}}|$BACKLOG_DOMAIN|g" \
  -e "s|{{BACKLOG_WATCH_USER_IDS}}|${BACKLOG_WATCH_USER_IDS:-none}|g" \
  -e "s|{{BACKLOG_WATCH_NAMES}}|${BACKLOG_WATCH_NAMES:-nobody}|g" \
  "$DIR/prompt.txt")"

FULL_PROMPT="$PROMPT

Run type: $MODE. Current time: $(date '+%Y-%m-%d %H:%M %Z').
Last summary sent: $LAST_AT.
Excluded Backlog project keys: ${EXCLUDE:-none}"

log "running summary ($MODE)"
cd "$DIR"
OUT=$("$CLAUDE" -p "$FULL_PROMPT" \
  --allowedTools "mcp__new-jira__jira_search mcp__backlog__get_issues mcp__slack__slack_post_message" 2>&1)
log "claude said: $OUT"

if [[ "$OUT" == *POSTED* ]]; then
  date '+%Y-%m-%d %H:%M %Z' > "$STATE/last-at"
  [[ $MODE == auto ]] && date +%F > "$STATE/last-date"
fi
