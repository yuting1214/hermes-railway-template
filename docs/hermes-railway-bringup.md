# Hermes-Agent on Railway — bring-up recipe

A self-owned Railway template for **hermes-agent** (NousResearch), driven from
your Mac over `railway ssh` + tmux, with the agent **profile** treated as a
portable, backed-up identity. No third-party UI — only Hermes-team artifacts.

This mirrors the terminal/volume/OAuth-over-tmux model of
`doc/railway-claude-bringup-recipe.md`, adapted to Hermes.

> Verified against hermes-agent **v0.16.0**. A few exact strings (the Codex model
> id; the dashboard health path) are noted inline — confirm them live during your
> first deploy with `hermes models` / `hermes --help`.

---

## Concepts (read once)

- **`HERMES_HOME`** — the data dir. Everything the agent *is* lives here:
  `config.yaml` (model/harness/loop), `SOUL.md` (persona), `skills/`,
  `memories/`, `sessions/`, `state.db`, `cron/`, `.env`, `.auth.json`.
  We put it on a **Railway volume** so it survives redeploys.
  - SLIM variant → volume at **`/data`**.
  - FULL variant → volume at **`/opt/data`** (the official image hardcodes this).
- **Profile** — a self-contained `HERMES_HOME` under `profiles/<name>/` (the bare
  home is the `default` profile). It is the unit you **export/import** to move the
  agent between machines. `hermes profile export` excludes secrets (`.env`,
  `.auth.json`) by design.
- **Gateway** — `hermes gateway run` is the always-on response engine: it hosts
  the messaging adapters (Telegram/Discord/Slack) + the agent loop, so the bot
  answers 24/7 with nobody SSH'd in. It is the container's PID-1 foreground
  process (auto-restarted by Railway on crash, and by s6 in the full image).
- **Two ways in:**
  - terminal — `railway ssh -s hermes` → `hermes chat` / `hermes -z "…"`,
  - messaging — Telegram et al., served by the gateway.

---

## Prerequisites

- Railway account + `railway` CLI (`brew install railway`, then `railway login`).
- A ChatGPT subscription for **Codex** auth (provider `openai-codex`).
- `hermes` installed locally (you already have this) — needed to mint the Codex
  token locally before pushing it up.
- Optional messaging: a Telegram bot token from @BotFather.

Pick a variant:
- **slim** — CLI + gateway only, smallest RAM. Best default.
- **full** — official image + first-party `hermes dashboard` web UI (heavier).

---

## Phase 1 — Project + volume

```bash
cd hermes-agent/variants/slim        # or variants/full
railway init --name "hermes"         # creates the project (pick your workspace)
railway add --service hermes         # creates + links the service

# Volume at the variant's HERMES_HOME. NOTE (CLI 4.30.2): `railway volume add`
# takes only -m/--mount-path and attaches to the *linked* service — there is no
# -s flag. The Dockerfiles deliberately omit a Docker `VOLUME` instruction
# because Railway rejects it ("docker VOLUME ... is not supported").
railway volume add -m /data          # slim   (linked service = hermes)
# railway volume add -m /opt/data    # full
```

## Phase 2 — First deploy

```bash
# from the variant directory (build context = this dir)
railway up -s hermes -d
railway logs -s hermes -d        # watch it boot
```

The slim container idles for `railway ssh` until a messaging token is set; the
full container also starts the dashboard. Verify the binary:

```bash
railway ssh -s hermes -- hermes --version
```

> **Disable auto-sleep.** In the Railway dashboard, ensure the service is **not**
> set to serverless/sleep-on-idle — a sleeping service stops answering messages.
> The slim worker has no public HTTP port, so it runs as an always-on worker.

## Phase 3 — Codex (ChatGPT subscription) auth

Codex auth is a **device-authorization flow**: it prints a URL + a short code, you
authorize in any browser, and the CLI polls to completion — **no port-forwarding,
no token copying**, so it works cleanly over `railway ssh`.

> **Command note (verified):** these images build from upstream `@main`, where the
> old `hermes login` was **removed**. Use **`hermes auth add`** instead. The CLI
> prints: *"Open https://auth.openai.com/codex/device and enter code XXXX-XXXX"*.

Run it (works the same on `hermes` slim or `hermes-full`; substitute the service):

```bash
cd hermes-agent/variants/slim                 # the linked project dir
railway ssh -s hermes -- hermes auth add openai-codex --type oauth --no-browser
#   → open the printed URL on your Mac, enter the code, sign in with ChatGPT.
#     The command polls and finishes on its own ("Added openai-codex OAuth credential").

# set the model + verify (single-token prompt; railway ssh splits spaces):
railway ssh -s hermes -- hermes config set model openai-codex/gpt-5.4
railway ssh -s hermes -- hermes auth status openai-codex     # → "logged in"
railway ssh -s hermes -- hermes -z ping                      # → pong
```

`auth.json` lands in `$HERMES_HOME/auth.json` on the volume, so it persists across
redeploys. (`scripts/onboard-codex.sh` opens an interactive shell if you prefer to
run the steps by hand. `hermes model` is the interactive provider/model picker;
`hermes -m <model> -z …` overrides per-call.)

## Phase 4 — Terminal interaction

```bash
# attach to the persistent session and chat:
railway ssh -s hermes
#   $ tmux attach -t hermes
#   $ hermes chat

# one-shot from your Mac — single-token prompt (railway ssh splits spaces):
railway ssh -s hermes -- hermes -z ping
# for multi-word prompts use the interactive shell instead:
#   railway ssh -s hermes   →   hermes -z "summarize today's logs"
```

tmux keeps your session alive across disconnects; it is independent of the
gateway, so attaching/detaching never interrupts the responder. (`railway ssh -s
hermes --session` also opens a native tmux session and auto-installs tmux.)

## Phase 5 — Always-on Telegram (the response engine)

```bash
railway variable set 'TELEGRAM_BOT_TOKEN=123456:ABC...' -s hermes
railway redeploy -s hermes -y
railway logs -s hermes -d        # expect the Telegram adapter to connect
```

On boot the entrypoint writes the token into `/data/.env` and (auto mode) starts
`hermes gateway run`. Message your bot from your phone **with no SSH session
open** — it should reply. Configure platforms/allowed chats with
`railway ssh -s hermes -- hermes gateway setup`.

State (`gateway_state.json`, per-chat history) lives on the volume, so a
`railway redeploy` resumes conversations.

## Phase 6 — Back up the profile (cross-device recovery)

The volume covers redeploys. For off-box backup, pull an export and ship it.
Run from the **linked** project dir (where you ran `railway init`):

```bash
cd hermes-agent/variants/slim

# just pull locally:
SERVICE=hermes PROFILE=default ../../scripts/backup-pull.sh

# pull + commit to a PRIVATE git repo:
SERVICE=hermes PROFILE=default SINK=git GIT_DIR=~/hermes-backups ../../scripts/backup-pull.sh

# pull + push to Cloudflare R2 (creds from your env, never hardcoded):
SINK=r2 R2_BUCKET=my-bucket R2_ENDPOINT=https://<acct>.r2.cloudflarestorage.com \
  ../../scripts/backup-pull.sh
```

> Verified live: `backup-pull.sh` exports `default`, streams it down, and
> validates the tarball (`tar tzf`) — it contains `SOUL.md`/`skills`/`memories`
> /`sessions` etc.

Automate it: register a Hermes cron job (`railway ssh -s hermes -- hermes cron …`)
that runs `hermes profile export` to `/data/backups/` on a schedule, and/or run
`backup-pull.sh` from your Mac on a timer.

## Phase 7 — Restore on a new device / fresh service

`railway ssh` can't reliably stream a file *into* a container (see limitations
below), so restore fetches the archive **by URL** from inside the container
(`curl` is present). Host the tarball at a URL the container can reach — an R2
pre-signed URL, or a raw private-repo URL with a token.

```bash
# deploy a fresh service + volume (Phases 1-2), then from the linked dir:
cd hermes-agent/variants/slim
SERVICE=hermes NAME=default ARCHIVE_URL="https://…/default-XXXX.tar.gz" \
  ../../scripts/restore-profile.sh

# re-add secrets (NOT in the export):
railway variable set 'TELEGRAM_BOT_TOKEN=...' -s hermes
../../scripts/onboard-codex.sh   # re-establish Codex auth (device flow)
```

`hermes profile list` / `hermes profile show <name>` should show the restored
agent, and it should recall its memories.

## Phase 8 (full variant only) — the Hermes dashboard

The `full` variant is **built from source** (Node 22 builds the `web/` UI → a
Python image serves `hermes dashboard` + gateway). Why: the official
`ghcr.io/nousresearch/hermes-agent` image is a **private** GHCR package (Railway
can't pull it) and the built UI isn't in the git package. Deploy it like the slim
one but with the volume at **`/opt/data`**:

```bash
cd hermes-agent/variants/full
railway init --name "hermes" && railway add --service hermes-full   # or add to an existing project
railway volume add -m /opt/data
railway up -s hermes-full -d
```

**The dashboard auth gate is mandatory on a public bind.** Binding to `0.0.0.0`
without an auth provider makes `hermes dashboard` refuse to start. Pick one (set as
Railway variables — the entrypoint also waives the root-gateway guard via
`HERMES_ALLOW_ROOT_GATEWAY=1`):

```bash
# A) simplest — username/password gate (no OAuth IDP):
railway variable set 'HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin'        -s hermes-full
railway variable set 'HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=<strong-pw>'  -s hermes-full
railway variable set 'HERMES_DASHBOARD_BASIC_AUTH_SECRET=<32+ random>'   -s hermes-full  # stable sessions across restarts
railway redeploy -s hermes-full -y
railway domain -s hermes-full            # public URL → redirects to /login

# B) Nous Portal OAuth instead:  railway ssh -s hermes-full -- hermes dashboard register
```

Do **not** use `--insecure` / `HERMES_DASHBOARD_INSECURE=1` on a public domain — it
serves an unauthenticated dashboard (full config + session access). The dashboard
reads the same `/opt/data` profile as the gateway.

---

## Operations cheat-sheet

| Task | Command |
|------|---------|
| Tail logs | `railway logs -s hermes -d` |
| Shell | `railway ssh -s hermes` → `tmux attach -t hermes` |
| One-shot | `railway ssh -s hermes -- hermes -z ping` (multi-word → interactive shell) |
| Gateway status | `railway ssh -s hermes -- hermes gateway status` |
| List profiles | `railway ssh -s hermes -- hermes profile list` |
| New profile | `railway ssh -s hermes -- hermes profile create <name>` |
| Set model | `railway ssh -s hermes -- hermes config set model '<provider/model>'` |
| Set secret | `railway variable set 'KEY=val' -s hermes` (legacy: `variables --set`) |
| Redeploy | `railway redeploy -s hermes -y` |
| Backup | `SERVICE=hermes ../../scripts/backup-pull.sh` |
| Restore | `ARCHIVE_URL=… ../../scripts/restore-profile.sh` |
| Codex auth | `../../scripts/onboard-codex.sh` (device flow) |

## Gotchas

- **Volume mount path differs by variant**: `/data` (slim) vs `/opt/data` (full).
  Mount the volume at the right one or the agent boots with an empty home.
- **No serverless sleep** — it would suspend the responder.
- **No HTTP healthcheck on slim** — it has no web port; a healthcheck would kill a
  healthy worker. (The full variant can use the dashboard for a healthcheck.)
- **Secrets never leave in a backup** — re-establish auth (`onboard-codex.sh`) +
  re-set Railway vars on restore.
- **`railway ssh` quirks (verified on CLI 4.30.2)** — these shape the scripts:
  - Only a **single simple command** after `--` is reliable. Complex
    `sh -c "… | … > …"` / `if/then` strings get mangled ("then unexpected").
  - **stdin piped into** `railway ssh -- cmd` **hangs** — so you can't stream a
    file *up*. Reads work (`railway ssh -- base64 file` → decode locally);
    writes go via `curl`-from-URL inside the container.
  - Output is **CRLF**, so base64 is decoded CR-tolerantly (the scripts use
    python3 / strip `\r`).
  - The project **link is directory-scoped** — run the scripts from the dir where
    you `railway init`/`railway link`ed (or set `RAILWAY_TOKEN`).
- **Latest vs reproducible** — slim builds from `git@main` (always latest). Pin
  `--build-arg HERMES_REF=v0.16.0` for a reproducible image.
