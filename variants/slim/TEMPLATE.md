# Deploy and Host Hermes Agent (Slim) on Railway

[Hermes](https://github.com/nousresearch/hermes-agent) is a self-improving AI agent
by **Nous Research** that connects to your messaging channels, learns from every
interaction, creates its own skills, and gets more capable over time. This **Slim**
template runs it **headless** — CLI plus an always-on messaging gateway, no web UI —
for the smallest possible footprint (**~160 MB RAM**).

![Hermes Agent — CLI splash showing 31 tools and 76 skills](https://raw.githubusercontent.com/yuting1214/hermes-railway-template/7b6ac00/assets/onboarding.png)

## About Hosting Hermes Agent (Slim)

The Slim variant keeps an always-on `hermes gateway` answering Telegram, Discord, and
Slack around the clock, while persisting skills, memories, and sessions automatically
so they survive redeploys. It ships **no dashboard, no Node, and no headless browser**
— just the agent and its gateway, tuned to idle around **~160 MB**. Because Railway
bills by **GB-hour of memory**, a leaner agent means a **lower monthly bill** for the
same self-improving agent. Storage, persistence, and low-memory tuning are handled for
you — you only bring an LLM key.

## Why Deploy Hermes Agent (Slim) on Railway?

Railway charges for the RAM you use, and this variant is built to use as little as
possible:

| | this template (slim) | typical Hermes template | browser-bundled template |
|---|---|---|---|
| Steady RAM | **~160 MB** | ~300–500 MB | 1–4 GB |
| Web dashboard | none (CLI) | yes | yes |
| Node / Playwright / Chromium | none | sometimes | yes |

- **Lowest RAM, lowest bill** — the leanest way to keep a Hermes agent online 24/7.
- **Self-improving** — agent-curated memory, autonomous skill creation, cron jobs.
- **Multi-channel** — Telegram, Discord, Slack, and more.
- **Pinned to a tested release, not a moving branch** — currently **hermes-agent
  v0.20.0** (upstream tag `v2026.8.3`), so what you deploy is reproducible rather
  than whatever landed on `main` this morning.
- **Your keys, your data** — nothing is bundled and no credentials ship with the template.

## What Slim Leaves Out (and How to Get It Back)

Slim ships no Node, no ffmpeg, and no headless browser — that is where the RAM and
image savings come from. Upstream treats these as optional, install-on-demand
dependencies, so nothing is permanently lost:

| Feature | In Slim | How to get it |
|---|---|---|
| Telegram / Discord / Slack gateway, skills, memory, cron | ✅ included | — |
| File search (ripgrep) | ✅ included | — |
| `npx`-based MCP servers, terminal UI | ⚙️ on demand | Hermes installs Node 22 into your volume on first use (**~200 MB of volume**) |
| TTS voice-message conversion (ffmpeg) | ➖ skipped | `apt-get install ffmpeg` in a fork, or use text replies |
| Local headless browser (Chromium) | ❌ not supported | Use hosted browsing — `exa`, `firecrawl`, `parallel-web`, or Browserbase — or deploy the Full variant and add a browser there |

**Why no local browser:** Chromium needs ~25 X/GTK/NSS system libraries and ~184 MB
of binary. Bundling it is what pushes other Hermes templates to 1–4 GB of RAM and
multi-GB images — the exact cost this variant exists to avoid. API-based browsing
tools give an agent the same capability without a browser in the container.

**Note on the on-demand Node install:** it writes to the persistent volume (so it
survives redeploys) and Railway bills volume storage, so it is worth knowing it can
add ~200 MB the first time a tool needs it.

## Common Use Cases

- A **24/7 personal assistant** on Telegram or Discord that remembers context and
  improves over time.
- A **self-improving ops/support bot** that builds its own skills from real tasks.
- A **cost-sensitive always-on agent** where minimizing Railway memory spend matters.

## Dependencies for Hermes Agent (Slim) Hosting

All you provide is an **LLM**: set an API-key variable (`OPENAI_API_KEY`,
`OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, …) on deploy, or sign in with a ChatGPT /
Codex subscription afterward. Optionally add a Telegram, Discord, or Slack bot token to
bring a channel online.

### Deployment Dependencies

- [Hermes Agent](https://github.com/nousresearch/hermes-agent) — open source by Nous
  Research; built from upstream source, pinned to release
  [`v2026.8.3`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.3)
  (**v0.20.0**, August 2026).

> Prefer a point-and-click web dashboard? Deploy the
> **[Full variant](https://railway.com/deploy/hermes-agent-full-self-improving-ai-agen?referralCode=jk_FgY&utm_medium=integration&utm_source=template&utm_campaign=generic)**
> — the first-party Nous dashboard, built from source — also on this marketplace.
