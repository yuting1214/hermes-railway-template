# Hermes Agent — Full (official dashboard)

Deploy and host a **self-improving [Hermes](https://github.com/nousresearch/hermes-agent)
agent by Nous Research** — an autonomous agent that connects to your messaging
channels, learns from every interaction, creates its own skills, and gets more
capable over time.

This is the **full** variant: everything in slim **plus the first-party Nous
`hermes dashboard`**, built from source — for point-and-click configuration and
monitoring.

## What you get

- **Official web dashboard** (not a third-party UI) — configure LLM providers,
  channels, and tools; watch live gateway logs; start/stop the agent — all in the
  browser, behind basic auth.
- **24/7 messaging** — Telegram, Discord, Slack and more, answered around the clock.
- **Self-improving** — agent-curated memory, autonomous skill creation, cron jobs.
- **Persistent identity** — config, skills, memories, sessions on a Railway
  **volume** (`/opt/data`), surviving redeploys.

Steady RAM ≈ **~300 MB** (dashboard + gateway) — on par with the leaner Hermes
templates, but shipping the *official* dashboard and **no headless browser**.
Low-memory tuning (`MALLOC_ARENA_MAX=2`) is baked into the image.

> Want the **lowest possible RAM / lowest Railway bill** and don't need a web UI?
> Deploy the **Slim** variant (~112 MB, CLI + gateway). (link added at publish)

## Setup

1. **Deploy** — a volume is attached at `/opt/data` automatically.
2. **Set dashboard credentials** (required — the dashboard refuses to start
   unauthenticated on a public domain):
   - `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`
   - `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`
   - `HERMES_DASHBOARD_BASIC_AUTH_SECRET`
3. **Open the generated domain**, log in, and configure your LLM provider + channels
   from the dashboard. (Or give it an LLM via `OPENAI_API_KEY` / Codex device-flow,
   same as slim.)

## Variables

| Variable | Required | Purpose |
|---|---|---|
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | **yes** | dashboard login user |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | **yes** | dashboard login password (set your own) |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | **yes** | session-signing secret (set your own) |
| `OPENAI_API_KEY` / `OPENROUTER_API_KEY` / … | optional* | LLM provider key (*or Codex device-flow / configure in dashboard) |
| `TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN` / … | optional | always-on messaging channel |

No credentials ship with this template — you set your own on deploy.

---

Hermes Agent is open source by **Nous Research**. This template builds the dashboard
from upstream source (`@main`, pinnable) — the official `hermes dashboard`, no
third-party UI.
