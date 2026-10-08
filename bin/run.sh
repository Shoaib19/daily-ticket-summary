#!/bin/zsh
# Posts a Jira + Backlog ticket summary to your Slack DM.
#   auto (launchd, every 3 min): once per weekday, within your configured window,
#                                 only when you're at the unlocked laptop, and only
#                                 once Jira/Backlog/Slack are all reachable (waits
#                                 up to ~2.5 min; if still down, the next 3-min
#                                 check tries again).
#   manual (run.sh --now):       immediately (no day/hour/lock checks), but still
#                                 waits up to 90s for the network before giving up.
#
# You should not normally run this file directly — use `bin/install.sh` once,
# then the `ticket-summary` shortcut it adds for manual runs.

set -uo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$DIR/state"
LOGFILE="$HOME/Library/Logs/daily-ticket-summary.log"
mkdir -p "$STATE" "$(dirname "$LOGFILE")"
log() { echo "$(date '+%F %T') $*"; }

# Waits until every URL in $@ answers, or gives up after $1 seconds (polling every $2).
# Returns 0 once all are reachable, 1 if it timed out waiting.
wait_for_network() {
  local max_wait=$1 poll=$2; shift 2
  local hosts=("$@") waited=0 all_ok h
  while (( waited < max_wait )); do
    all_ok=1
    for h in "${hosts[@]}"; do
      curl -sI --max-time 5 "$h" >/dev/null 2>&1 || { all_ok=0; break; }
    done
    (( all_ok )) && return 0
    [[ $MODE == manual ]] && log "waiting for network... (${waited}s, still can't reach $h)"
    sleep "$poll"
    waited=$(( waited + poll ))
  done
  return 1
}

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

# Alerts you WITHOUT going through Claude at all — for when Claude itself is
# the thing that's broken (e.g. its own login expired) and so can't send the
# usual Slack message. Only fires once per day (auto mode retries every 3 min,
# and you don't want a pile of copies of the same alert).
notify_failure() {
  local reason="$1"
  [[ "$(cat "$STATE/last-fail-alert" 2>/dev/null)" == "$(date +%F)" ]] && return 0
  date +%F > "$STATE/last-fail-alert"

  osascript -e "display notification \"${reason:0:200}\" with title \"Ticket summary failed\" sound name \"Basso\"" >/dev/null 2>&1

  if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
    curl -s -X POST https://slack.com/api/chat.postMessage \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data-binary @- >/dev/null 2>&1 <<EOF
{"channel":"$SLACK_USER_ID","text":"⚠️ Ticket summary automation failed $MAX_ATTEMPTS times today and could not post the real summary. Last error:\n\n${reason:0:500}\n\nStopping until tomorrow. Check ~/Library/Logs/daily-ticket-summary.log or run ticket-summary by hand."}
EOF
  fi
}

MAX_ATTEMPTS=3

# Reads state/fail-count ("YYYY-MM-DD:N"). Returns true if today already hit
# MAX_ATTEMPTS failed auto-mode attempts (so it stops trying until tomorrow,
# instead of retrying every 3 min for hours on a persistent failure).
attempts_exhausted_today() {
  local stored stored_date stored_count
  stored="$(cat "$STATE/fail-count" 2>/dev/null)"
  stored_date="${stored%%:*}"; stored_count="${stored##*:}"
  [[ "$stored_date" == "$(date +%F)" && "${stored_count:-0}" -ge $MAX_ATTEMPTS ]]
}

# Increments and persists today's failure count (resets automatically once the
# stored date is no longer today — that's the "normal flow again tomorrow" part).
# Echoes the new count.
record_failure() {
  local stored stored_date stored_count new_count
  stored="$(cat "$STATE/fail-count" 2>/dev/null)"
  stored_date="${stored%%:*}"; stored_count="${stored##*:}"
  if [[ "$stored_date" == "$(date +%F)" ]]; then
    new_count=$(( ${stored_count:-0} + 1 ))
  else
    new_count=1
  fi
  echo "$(date +%F):$new_count" > "$STATE/fail-count"
  echo "$new_count"
}

MODE=auto
[[ "${1:-}" == "--now" ]] && MODE=manual

if [[ $MODE == auto ]]; then
  [[ $(date +%u) -le 5 ]] || exit 0                                          # weekdays only (1=Mon…7=Sun)
  HOUR=$(( 10#$(date +%H) ))                                                 # 10# forces base-10 (avoids "08"/"09" octal errors)
  (( HOUR >= WINDOW_START_HOUR && HOUR < WINDOW_END_HOUR )) || exit 0        # inside the configured window
  [[ "$(cat "$STATE/last-date" 2>/dev/null)" != "$(date +%F)" ]] || exit 0   # only once per day
  attempts_exhausted_today && exit 0                                        # already failed 3x today → stop, try again tomorrow
  ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes' && exit 0     # screen locked → not at the laptop yet
else
  exec > >(tee -a "$LOGFILE") 2>&1                                           # manual: show output AND log it
fi

if [[ $MODE == auto ]]; then
  wait_for_network 150 10 "https://slack.com" "$JIRA_URL" "https://$BACKLOG_DOMAIN" || exit 0   # still down after ~2.5 min → next 3-min check retries
else
  if ! wait_for_network 90 5 "https://slack.com" "$JIRA_URL" "https://$BACKLOG_DOMAIN"; then
    log "Network never came back after 90s — reconnect and run ticket-summary again."
    exit 1
  fi
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
elif [[ $MODE == auto ]]; then
  ATTEMPT_NUM=$(record_failure)
  log "attempt $ATTEMPT_NUM of $MAX_ATTEMPTS failed"
  (( ATTEMPT_NUM >= MAX_ATTEMPTS )) && notify_failure "$OUT"   # only alert once all attempts for today are used up, not on the first failure
fi
