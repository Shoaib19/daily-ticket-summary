# Daily Ticket Summary

A DM to yourself in Slack, listing:
- your own Jira tickets that aren't done yet, and
- your teammates' Backlog tickets (whoever you choose to watch),

so you know what's moving before you start your day — without opening either
tool.

It arrives automatically on weekday mornings, and you can also trigger it
yourself anytime with one word: `ticket-summary`.

**Requires a Mac.** It uses macOS's own scheduler (`launchd`), so it won't
work on Windows or Linux.

It is **read-only**: it can only look up tickets and post one Slack message.
It cannot create, edit, close, or comment on anything.

---

## Before you start

You'll need, all free:
- A Mac, logged in with your own account.
- Access to the office's Jira and Backlog with your own account.
- Slack access in the office workspace.
- About 10–15 minutes, mostly spent copying tokens (see step 4).

---

## Install

**1. Get this folder onto your Mac.**
Ask whoever shared this with you for the repository link, then in Terminal:
```
git clone <REPO_URL>
cd daily-ticket-summary
```
(If you were just handed the folder directly — e.g. AirDropped — skip
straight to step 2, using that folder.)

**2. Open Terminal.**
Press `Cmd + Space`, type `Terminal`, press Enter. Then move into the folder
you just downloaded, e.g.:
```
cd ~/Downloads/daily-ticket-summary
```

**3. Run the installer.**
```
bin/install.sh
```
The first time, it will stop and tell you to fill in `config.env` — that's
expected, not an error.

**4. Fill in your tokens.**
Follow **[docs/getting-your-tokens.md](docs/getting-your-tokens.md)**
step by step. It explains, click by click, where to get each value — no
prior Jira/Backlog/Slack admin experience needed.

**5. Run the installer again.**
```
bin/install.sh
```
This time it should finish with `== Install complete ==`.

**6. Get your first summary.**
Open a **new** Terminal window (important — this is how it picks up the new
shortcut), then run:
```
ticket-summary
```
Within a minute or so, a message should land in your Slack DMs.

---

## Everyday use

**Automatic:** Monday–Friday, the first time you're at your unlocked laptop
with internet, between the hours set in `config.env` (default 9:00–12:00),
you'll get the summary without doing anything.

**Manual, for special days:** type `ticket-summary` in Terminal anytime — a
5 PM check before a big meeting, a Saturday you're catching up, whenever.
This never interferes with the next automatic run.

**Tune who/what it watches**, no reinstall needed — just edit and save:
- `config.env` → `BACKLOG_WATCH_USER_IDS` / `BACKLOG_WATCH_NAMES`: which
  teammates' Backlog tickets to include. Leave both blank for Jira-only.
  (See docs/getting-your-tokens.md, section 5, to find IDs.)
- `backlog-exclude.txt` → project keys to leave out (one per line). You'll
  see each ticket's project key in brackets in the summary itself, so it's
  easy to decide what to drop after your first run.

---

## Checking it's healthy

```
bin/doctor.sh
```
Lists every piece of the setup with ✅ or ❌ and, for anything broken, a
plain-English pointer to the fix.

## Something not working?

See **[docs/troubleshooting.md](docs/troubleshooting.md)** for the most
common issues and their fixes.

## Uninstalling

```
bin/uninstall.sh
```
Removes the scheduled job and the `ticket-summary` shortcut. Leaves
`config.env` and your registered MCP servers alone, in case you turn it back
on later.

---

## Privacy & security

- Every token lives only in your own `config.env`, on your own Mac. It's
  never read by anyone else, never uploaded, and is listed in `.gitignore`
  so it can't be committed to git by accident.
- Still, this repository should stay **private** — it contains the office's
  internal Jira and Backlog addresses.
- Never paste the contents of `config.env` into Slack, email, or a shared
  document, even to ask for help. Screenshot the error instead.

---

## What's inside

| File | Purpose |
|---|---|
| `config.example.env` | Template — copy to `config.env` and fill in |
| `backlog-exclude.example.txt` | Template — copy to `backlog-exclude.txt` |
| `prompt.txt` | The instructions Claude follows to build each summary |
| `bin/install.sh` | One-time setup: checks tools, registers MCP servers, schedules the job |
| `bin/run.sh` | Does the actual work — called automatically and by `ticket-summary` |
| `bin/find-backlog-ids.sh` | Looks up a teammate's Backlog ID by name |
| `bin/doctor.sh` | Health check with plain-English explanations |
| `bin/uninstall.sh` | Removes the scheduled job and shortcut |
| `templates/launchd.plist.template` | Blueprint for your personal scheduled job |
| `docs/getting-your-tokens.md` | Click-by-click token setup |
| `docs/troubleshooting.md` | Common problems and fixes |
