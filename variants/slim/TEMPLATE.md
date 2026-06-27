# Hermes Agent (Slim) — Cheapest Self-Improving AI Agent on Railway

Deploy and host a **self-improving [Hermes](https://github.com/nousresearch/hermes-agent)
agent by Nous Research** — an autonomous agent that connects to your messaging
channels, learns from every interaction, creates its own skills, and gets more
capable over time.

This is the **slim** variant: **CLI + always-on messaging gateway, no web UI** —
the smallest possible footprint.

## Why slim — Railway bills by RAM

| | this template (slim) | typical Hermes template | browser-bundled template |
|---|---|---|---|
| Steady RAM | **~112 MB** | ~300–500 MB | 1–4 GB |
| Web dashboard | none (CLI) | yes | yes |
| Node / Playwright / Chromium | none | sometimes | yes |

Railway charges per **GB-hour of memory**, so a leaner agent is a **lower monthly
bill** — for the same 24/7 self-improving agent. Slim ships no dashboard, no Node,
and no headless browser, and tunes glibc (`MALLOC_ARENA_MAX=2`) so the always-on
gateway idles around **~112 MB**.

> Want a point-and-click web dashboard instead? Deploy the **Full** variant — the
> first-party Nous dashboard, built from source. (link added at publish)

## What you get

- **24/7 messaging** — Telegram, Discord, Slack (and more) answered around the clock
  by an always-on `hermes gateway`.
- **Self-improving** — agent-curated memory, autonomous skill creation, cron jobs.
- **Persistent identity** — skills, memories, sessions, and auth live on a Railway
  **volume** (`/data`), surviving redeploys.
- **Terminal-native ops** — drive it over `railway ssh` + `tmux` and `hermes chat`.

## Setup (2 minutes)

1. **Deploy** — a volume is attached at `/data` automatically.
2. **Give it an LLM** — either:
   - set an API-key variable (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`, …), **or**
   - use a ChatGPT/Codex subscription via device-flow:
     ```bash
     railway ssh -s hermes -- hermes auth add openai-codex --type oauth --no-browser
     ```
     (open the printed URL, enter the code, approve — the token persists on the volume)
3. **Connect a channel** — set `TELEGRAM_BOT_TOKEN` (or `DISCORD_BOT_TOKEN` /
   `SLACK_BOT_TOKEN`). The gateway auto-starts and stays up.

That's it — your agent is live and answering.

## Variables

| Variable | Required | Purpose |
|---|---|---|
| `OPENAI_API_KEY` / `OPENROUTER_API_KEY` / `ANTHROPIC_API_KEY` | optional* | LLM provider key (*or use Codex device-flow) |
| `TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN` / `SLACK_BOT_TOKEN` | optional | enable an always-on messaging channel |
| `HERMES_KEEPALIVE` | optional | `auto` (default), `gateway`, or `idle` |

Low-memory tuning (`MALLOC_ARENA_MAX=2`) ships baked into the image — nothing to set.

---

Hermes Agent is open source by **Nous Research**. This template builds from upstream
(`@main`, pinnable). It bundles no third-party UI — only Hermes-team artifacts.
