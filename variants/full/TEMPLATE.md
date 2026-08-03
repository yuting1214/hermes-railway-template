# Deploy and Host Hermes Agent (Full) on Railway

[Hermes](https://github.com/nousresearch/hermes-agent) is a self-improving AI agent
by **Nous Research** that connects to your messaging channels, learns from every
interaction, creates its own skills, and gets more capable over time. This **Full**
template runs the agent **plus the first-party Nous `hermes dashboard`** — built from
source — so you can configure and monitor everything from your browser.

![Hermes Agent — the official Nous web dashboard](https://raw.githubusercontent.com/yuting1214/hermes-railway-template/30a9321/assets/dashboard.png)

## About Hosting Hermes Agent (Full)

The Full variant serves the **official Hermes web dashboard** behind basic auth (not a
third-party UI): configure LLM providers, channels, and tools; watch live gateway
logs; and start/stop the agent — all point-and-click. Alongside it runs the same
always-on `hermes gateway` that answers Telegram, Discord, and Slack 24/7. Config,
skills, memories, and sessions persist on a Railway **volume** (`/opt/data`) so they
survive redeploys. Steady memory is **~300 MB** (dashboard + gateway) with **no
headless browser** bundled — lean for what it offers.

## Why Deploy Hermes Agent (Full) on Railway?

- **Official dashboard, from source** — the genuine Nous `hermes dashboard`, not a
  community wrapper.
- **Point-and-click setup** — pick providers/channels/tools and watch logs in the
  browser; no terminal required.
- **Self-improving** — agent-curated memory, autonomous skill creation, cron jobs.
- **Lean for a UI build** — ~300 MB steady, no Chromium/Playwright.
- **Pinned to a tested release, not a moving branch** — currently **hermes-agent
  v0.19.1** (upstream tag `v2026.7.30`), so what you deploy is reproducible rather
  than whatever landed on `main` this morning.
- **Your keys, your data** — nothing is bundled and no credentials ship with the
  template.

> Want the **lowest possible RAM** and don't need a web UI? Deploy the
> **[Slim variant](https://railway.com/deploy/hermes-agent-slim-cheapest-self-improvin?referralCode=jk_FgY&utm_medium=integration&utm_source=template&utm_campaign=generic)**
> (~112 MB, CLI + gateway) — also on this marketplace.

## What Full Leaves Out (and How to Get It Back)

Full ships the dashboard and gateway, but deliberately **not** a headless browser,
ffmpeg, or a preinstalled Node runtime — those are what make other Hermes templates
1–4 GB. Upstream treats them as install-on-demand:

| Feature | In Full | How to get it |
|---|---|---|
| Official dashboard, gateway, skills, memory, cron | ✅ included | — |
| `npx`-based MCP servers, terminal UI | ⚙️ on demand | Hermes installs Node 22 into your volume on first use (**~200 MB of volume**) |
| TTS voice-message conversion (ffmpeg) | ➖ skipped | `apt-get install ffmpeg` in a fork, or use text replies |
| Local headless browser (Chromium) | ❌ not supported | Use hosted browsing — `exa`, `firecrawl`, `parallel-web`, or Browserbase |

Chromium needs ~25 X/GTK/NSS system libraries plus ~184 MB of binary; bundling it
would roughly triple this image and its memory floor. API-based browsing tools give
the agent the same capability without a browser in the container. The on-demand Node
install writes to the persistent volume (so it survives redeploys), and Railway bills
volume storage — worth knowing before a tool triggers it.

## Common Use Cases

- A **browser-managed personal assistant** you configure without touching a terminal.
- A **team agent** where non-CLI users tweak providers/channels via the dashboard.
- A **self-improving bot** with live observability of its gateway and logs.

## Dependencies for Hermes Agent (Full) Hosting

On deploy you choose your **dashboard login** — just a
`HERMES_DASHBOARD_BASIC_AUTH_USERNAME` and `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`.
The session-signing secret is **generated for you on first boot** and persisted to
the volume, so there's no opaque value to fill in. Then give it an **LLM**: set an
API-key variable (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`, …) or sign in with a
ChatGPT / Codex subscription — or just configure a provider from the dashboard
after it boots.

### Deployment Dependencies

- [Hermes Agent](https://github.com/nousresearch/hermes-agent) — open source by Nous
  Research; the dashboard is built from upstream source, pinned to release
  [`v2026.7.30`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.7.30)
  (**v0.19.1**, July 2026).
