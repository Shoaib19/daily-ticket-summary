# Getting your tokens

You need five things, filled into `config.env`. Every one of them is only ever
stored on your own Mac — nobody else can see them, and they are never uploaded
anywhere by this tool. Treat each one like a password: don't paste it into
Slack, email, or a chat message to anyone, including IT support.

Do these in order.

## 1. Jira API token

1. Go to **https://id.atlassian.com/manage-profile/security/api-tokens** and
   log in with the account you use for Jira.
2. Click **"Create API token"**.
3. Give it a name, for example `daily-ticket-summary`, and click **Create**.
4. Click **Copy**.
5. Open `config.env` and paste it as:
   ```
   JIRA_API_TOKEN=the-value-you-copied
   ```
   No quotes, no spaces around the `=`.
6. On the same line above it, set `JIRA_EMAIL` to the email address you use
   to log into Jira, e.g. `JIRA_EMAIL=you@innov8.jp`.

## 2. Backlog API key

1. Log into Backlog at **https://jins.backlog.jp**.
2. Click your avatar picture in the top-right corner, then **"Personal
   Settings"** (個人設定 in Japanese).
3. In the menu on the left, click **"API"**.
4. Click **"Register"** (登録) to create a new API key. Any name is fine.
5. Copy the key it shows you — Backlog only shows it once.
6. Paste it into `config.env`:
   ```
   BACKLOG_API_KEY=the-key-you-copied
   ```

## 3. Slack bot token + Team ID

This step creates a small Slack app whose only job is to send you a DM. It
can't read other people's messages or channels — it only gets the two
permissions you grant it below.

1. Go to **https://api.slack.com/apps** and click **"Create New App"** →
   **"From scratch"**.
2. Give it a name (e.g. "My Ticket Summary"), pick your workspace from the
   dropdown, and click **"Create App"**.
   - If the workspace doesn't appear, or app creation is blocked, your
     workspace requires admin approval for new apps. Ask your Slack admin (or
     Faisal) to either approve your request or create the app for you and
     hand you the bot token from step 6 below.
3. In the left sidebar, click **"OAuth & Permissions"**.
4. Scroll down to **"Scopes" → "Bot Token Scopes"** and click **"Add an OAuth
   Scope"**. Add both of these:
   - `chat:write`
   - `users:read`
5. Scroll back to the top of that page and click **"Install to Workspace"**,
   then **"Allow"** on the screen that follows.
6. Still on the **"OAuth & Permissions"** page, copy the **"Bot User OAuth
   Token"** — it starts with `xoxb-`. Paste it into `config.env`:
   ```
   SLACK_BOT_TOKEN=xoxb-the-token-you-copied
   ```
7. Now get your workspace's Team ID:
   - Open **https://api.slack.com/methods/auth.test/test** in your browser
     (while logged into the same Slack account).
   - Paste your bot token into the **"token"** field on that page.
   - Click **"Test Method"**.
   - In the result on the right, find `"team_id"` — it's a short code
     starting with `T`. Paste it into `config.env`:
     ```
     SLACK_TEAM_ID=the-team-id-you-found
     ```

## 4. Your own Slack member ID

This tells the tool which Slack DM to send the summary to.

1. Open Slack (desktop app or in your browser).
2. Click your profile photo in the top-right corner → **"Profile"**.
3. On your profile card, click the **"⋮"** (more) menu → **"Copy member ID"**.
4. Paste it into `config.env`:
   ```
   SLACK_USER_ID=the-id-you-copied
   ```

## 5. (Optional) Finding teammates' Backlog IDs

If you'd also like the summary to include tickets assigned to specific
teammates (not just your own Jira tickets):

1. Finish steps 1–4 above, save `config.env`, and run `bin/install.sh` once
   (see the main README).
2. Run, for example:
   ```
   bin/find-backlog-ids.sh "Faisal" "Pravin" "Makoto"
   ```
3. It prints a table of names, IDs and emails. Copy the numeric IDs into
   `config.env` as `BACKLOG_WATCH_USER_IDS` (comma-separated, no spaces), and
   the names into `BACKLOG_WATCH_NAMES` in the same order.

You're done — go back to the main README and run `bin/install.sh` again.
