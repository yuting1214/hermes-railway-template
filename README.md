# hermes-agent — self-owned Railway template

Deploy and cultivate a [Hermes](https://github.com/nousresearch/hermes-agent)
agent on Railway, driven from your Mac terminal over `railway ssh` + tmux. Only
Hermes-team artifacts — no third-party UI. Your agent **profile** (prompt,
skills, harness/loop config, memories, cron) is treated as a portable identity
you can back up and recover on any device.

## Why this exists

The marketplace template (`praveen-ks-2001/hermes-agent-template`) works but
bundles a non-Hermes UI and extra deps. This template:

- ships **two clean variants** — `slim` (CLI + gateway, smallest RAM) and `full`
  (official image + the **first-party** `hermes dashboard` UI);
- is built around **`railway ssh` + tmux** for terminal onboarding and `hermes chat`;
- runs an **always-on response engine** (`hermes gateway run`) so Telegram/Discord
  keep getting answered 24/7;
- builds from **latest upstream** (`git@main`, pinnable);
- makes the **profile** portable via `hermes profile export/import` + a Railway
  volume + off-box backup (git / R2 / ssh-stream).

## Layout

```
hermes-agent/
├── variants/
│   ├── slim/     Dockerfile + railway.json   — python-slim, CLI+gateway, vol /data
│   └── full/     Dockerfile + railway.json   — official image + dashboard, vol /opt/data
├── scripts/      (run from the linked project dir, e.g. variants/slim)
│   ├── onboard-codex.sh    open a shell to run the Codex device-flow login
│   ├── backup-pull.sh      export a profile + pull it down (+ git/R2 sink)
│   └── restore-profile.sh  fetch a profile tarball by URL + import it
└── docs/
    └── hermes-railway-bringup.md   ← full step-by-step recipe
```

## Quickstart (slim)

```bash
cd hermes-agent/variants/slim
railway init --name "hermes" && railway add --service hermes
railway volume add -m /data          # attaches to the linked service (no -s flag)
railway up -s hermes -d

# auth (Codex / ChatGPT subscription) — device flow, no port-forward needed:
SERVICE=hermes ../../scripts/onboard-codex.sh    # opens a shell; run the login,
                                                 # open the URL, enter the code

# use it
railway ssh -s hermes -- hermes -z 'reply: CODEX_OK'
railway ssh -s hermes                 # then: tmux attach -t hermes ; hermes chat
```

Add an always-on Telegram bot:

```bash
railway variables --set 'TELEGRAM_BOT_TOKEN=...' -s hermes
railway redeploy -s hermes -y
```

Back up / restore the agent:

```bash
SERVICE=hermes PROFILE=default SINK=git GIT_DIR=~/hermes-backups ../../scripts/backup-pull.sh
SERVICE=hermes NAME=default ARCHIVE_URL="https://…/default-XXXX.tar.gz" ../../scripts/restore-profile.sh
```

See **[docs/hermes-railway-bringup.md](docs/hermes-railway-bringup.md)** for the
full phased recipe, the full/UI variant, and gotchas.

For how Hermes works under the hood — conversation sessions & lifecycle, personas
vs profiles vs gateways (single- and multi-persona), and capabilities & safety
(granting credentialed tools, approvals/tirith/yolo, unattended-agent best
practices) — see the operator deep-dive:
**[docs/hermes-deep-dive.md](docs/hermes-deep-dive.md)**.

## Variant cheat-sheet

| | slim | full |
|---|---|---|
| Base | `python:3.12-slim` + pip `git@main` | `ghcr.io/nousresearch/hermes:latest` |
| `HERMES_HOME` / volume | `/data` | `/opt/data` |
| UI | none (CLI/`hermes chat`) | first-party `hermes dashboard` on `$PORT` |
| RAM | smallest (~200-400 MB) | heavier (Node + Playwright) |
| Keep-alive | `hermes gateway run` (entrypoint) | s6-supervised gateway + dashboard |

> CLI flags verified against hermes-agent v0.16.0 (`-z/--oneshot`,
> `gateway run`, `login --provider openai-codex --no-browser`,
> `profile export/import`, `config set model`, `dashboard --host/--port`).
> Pick the concrete Codex model id via the interactive `hermes model` picker.
