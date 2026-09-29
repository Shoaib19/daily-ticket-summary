# Troubleshooting

## "command not found: claude"

Claude Code isn't installed, or your terminal doesn't know where it is. Open
a new Terminal window (this matters — old windows don't pick up new
installs) and try again. If it still fails, install it:
```
curl -fsSL https://claude.ai/install.sh | sh
```

## `bin/install.sh` fails while registering an MCP server

The most common cause is a typo or extra space in `config.env`. Open it
(`open -e config.env`), check the value has no quotes, no trailing spaces,
and was copied in full, then run `bin/install.sh` again.

## `ticket-summary` says `claude said: FAILED: ...`

Whatever follows `FAILED:` is the actual reason — read it, it's usually
plain English (e.g. "invalid token", "channel not found"). Common causes:
- A token in `config.env` was copied incompletely or has expired — redo the
  matching step in `docs/getting-your-tokens.md`.
- `SLACK_USER_ID` is wrong — redo step 4 in that same doc.

## No message ever arrives, and there's no error

Run `bin/doctor.sh` — it checks every piece and tells you in plain words
what's missing.

If doctor.sh says everything is fine but the DM still isn't there, check
your Slack **Apps** section (bottom of the left sidebar, or search for the
app's name) — the bot may have posted there instead of your main DM list the
first time.

## The automatic (weekday morning) summary never fires

- It only fires once you're at your laptop, **unlocked**, inside the time
  window in `config.env` (`WINDOW_START_HOUR`–`WINDOW_END_HOUR`, default
  9–12). Outside that window, use `ticket-summary` manually instead.
- Check the log: `tail -30 ~/Library/Logs/daily-ticket-summary.log`
- Make sure the job is actually loaded:
  ```
  launchctl print gui/$(id -u)/com.<yourusername>.daily-ticket-summary
  ```
  (run `bin/doctor.sh` if you're not sure of the exact job name — it checks
  this for you).
- If you want to test the automatic path again today without waiting for
  tomorrow, delete its "already ran today" marker:
  ```
  rm state/last-date
  ```
  then wait up to 3 minutes while your laptop is unlocked and inside the
  time window.

## `launchctl bootstrap` says "Input/output error"

This usually means the job is already loaded. Run `bin/doctor.sh` to
confirm, or unload it first with `bin/uninstall.sh` and run `bin/install.sh`
again.

## I want to change who/what it watches

- **Your own Jira tickets**: nothing to configure — it's always "assigned to
  me, not yet done".
- **Which teammates' Backlog tickets**: edit `BACKLOG_WATCH_USER_IDS` and
  `BACKLOG_WATCH_NAMES` in `config.env` (see `docs/getting-your-tokens.md`,
  section 5, for how to find IDs).
- **Which Backlog projects to skip**: add their project key, one per line,
  to `backlog-exclude.txt`. You'll see the key in brackets after each
  ticket's title in a summary you already received.
- No reinstall needed for any of the above — just save the file. The next
  run (automatic or `ticket-summary`) picks it up.

## I want to stop it entirely

Run `bin/uninstall.sh`. It removes the scheduled job and the
`ticket-summary` shortcut, but leaves `config.env` and your MCP server
registrations in place in case you want to turn it back on later.
