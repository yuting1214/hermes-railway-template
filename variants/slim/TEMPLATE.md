# Deploy and Host Hermes Agent (Slim) on Railway

[Hermes](https://github.com/nousresearch/hermes-agent) is a self-improving AI agent
by **Nous Research** — it connects to your messaging channels, learns from every
interaction, creates its own skills, and gets more capable over time. This **Slim**
template runs it **headless** (CLI + always-on messaging gateway, no web UI) for the
**smallest possible footprint — ~112 MB RAM**.

## About Hosting Hermes Agent (Slim)

Hosting the Slim variant means running an always-on `hermes gateway` that answers
Telegram, Discord, and Slack around the clock, while persisting skills, memories,
sessions, and auth on a Railway **volume** (`/data`) so they survive redeploys. It
ships **no dashboard, no Node, and no headless browser** — just the agent and its
messaging gateway, with glibc tuned (`MALLOC_ARENA_MAX=2`) so the always-on engine
idles around **~112 MB**. Because Railway bills by **GB-hour of memory**, a leaner
agent means a **lower monthly bill** for the same 24/7 self-improving agent. You can
drive it from your terminal over `railway ssh` + `tmux` and `hermes chat`.

## Why Deploy Hermes Agent (Slim) on Railway?

Railway charges for the RAM you use, and this variant is built to use as little as
possible:

| | this template (slim) | typical Hermes template | browser-bundled template |
|---|---|---|---|
| Steady RAM | **~112 MB** | ~300–500 MB | 1–4 GB |
| Web dashboard | none (CLI) | yes | yes |
| Node / Playwright / Chromium | none | sometimes | yes |

- **Lowest RAM, lowest bill** — the leanest way to keep a Hermes agent online 24/7.
- **Self-improving** — agent-curated memory, autonomous skill creation, cron jobs.
- **Multi-channel** — Telegram, Discord, Slack, and more.
- **Your keys, your data** — bring an API key or a ChatGPT/Codex subscription; nothing
  is bundled and no credentials ship with the template.

## Common Use Cases

- A **24/7 personal assistant** on Telegram or Discord that remembers context and
  improves over time.
- A **self-improving ops/support bot** that builds its own skills from real tasks.
- A **cost-sensitive always-on agent** where minimizing Railway memory spend matters.

## Dependencies for Hermes Agent (Slim) Hosting

- An **LLM provider** — set an API-key variable (`OPENAI_API_KEY`,
  `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, …), **or** authenticate a ChatGPT/Codex
  subscription over `railway ssh`:
  ```bash
  railway ssh -s hermes -- hermes auth add openai-codex --type oauth --no-browser
  ```
- (optional) a **messaging bot token** — `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`,
  or `SLACK_BOT_TOKEN` — to bring an always-on channel online.

### Deployment Dependencies

- [Hermes Agent (upstream source)](https://github.com/nousresearch/hermes-agent) —
  built from `@main`, pinnable.
- A Railway **volume** mounted at `/data` (attached automatically) for persistent
  skills, memories, sessions, and auth.

### Variables

| Variable | Required | Purpose |
|---|---|---|
| `OPENAI_API_KEY` / `OPENROUTER_API_KEY` / `ANTHROPIC_API_KEY` | optional* | LLM provider key (*or use the Codex device-flow above) |
| `TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN` / `SLACK_BOT_TOKEN` | optional | enable an always-on messaging channel |
| `HERMES_KEEPALIVE` | optional | `auto` (default), `gateway`, or `idle` |

Low-memory tuning (`MALLOC_ARENA_MAX=2`) ships baked into the image — nothing to set.

> Want a point-and-click web dashboard instead? A **Full** variant — the first-party
> Nous dashboard, built from source — is also available on this marketplace.

---

Hermes Agent is open source by **Nous Research**. This template bundles no third-party
UI — only Hermes-team artifacts.
