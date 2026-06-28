# Deploy and Host Hermes Agent (Slim) on Railway

[Hermes](https://github.com/nousresearch/hermes-agent) is a self-improving AI agent
by **Nous Research** that connects to your messaging channels, learns from every
interaction, creates its own skills, and gets more capable over time. This **Slim**
template runs it **headless** — CLI plus an always-on messaging gateway, no web UI —
for the smallest possible footprint (**~112 MB RAM**).

## About Hosting Hermes Agent (Slim)

The Slim variant keeps an always-on `hermes gateway` answering Telegram, Discord, and
Slack around the clock, while persisting skills, memories, and sessions automatically
so they survive redeploys. It ships **no dashboard, no Node, and no headless browser**
— just the agent and its gateway, tuned to idle around **~112 MB**. Because Railway
bills by **GB-hour of memory**, a leaner agent means a **lower monthly bill** for the
same self-improving agent. Storage, persistence, and low-memory tuning are handled for
you — you only bring an LLM key.

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
- **Your keys, your data** — nothing is bundled and no credentials ship with the template.

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
  Research; built from upstream source.

> Prefer a point-and-click web dashboard? A **Full** variant — the first-party Nous
> dashboard, built from source — is also available on this marketplace.
