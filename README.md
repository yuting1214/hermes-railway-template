<img src="assets/icon.png" alt="Hermes / Nous Girl" width="92" align="right" />

# Hermes Agent — self-hosted Railway templates

One-click [Hermes](https://github.com/nousresearch/hermes-agent) — the self-improving
AI agent by **Nous Research** — on Railway, in **two lean variants**. Railway bills by
RAM, so these are built to use as little as possible. Only Hermes-team artifacts; no
third-party UI.

|  | **Slim** — lowest RAM | **Full** — official dashboard |
|---|---|---|
|  | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-agent-slim-cheapest-self-improvin?referralCode=jk_FgY&utm_medium=integration&utm_source=template&utm_campaign=generic) | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-agent-full-self-improving-ai-agen?referralCode=jk_FgY&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| Steady RAM | **~130 MB** | ~300 MB |
| Interface | CLI + always-on gateway | + first-party `hermes dashboard` (browser) |
| Deploy form | **nothing to fill** — one-click | username + password (signing secret auto-generated) |
| `HERMES_HOME` / volume | `/data` | `/opt/data` |

## Why this template

- **Lowest RAM, lowest bill** — slim idles **~130 MB** (no dashboard, no Node, no
  headless browser; glibc tuned via `MALLOC_ARENA_MAX=2`). Full ships the **official**
  Nous dashboard, **built from source**, still ~300 MB with **no Chromium**.
- **Self-improving** — agent-curated memory, autonomous skill creation, cron jobs.
- **24/7 messaging** — Telegram, Discord, Slack answered around the clock by an
  always-on `hermes gateway`.
- **Pinned to a real upstream release** — currently
  **[`v2026.7.30`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.7.30)
  (hermes-agent v0.19.1)**, not a moving `main`, so a deploy today and a deploy next
  month give you the same agent. Override with `--build-arg HERMES_REF=…`.
  What each upstream release changed is digested in
  **[docs/upstream-changelog.md](docs/upstream-changelog.md)** — no need to go read
  the release notes yourself.
- **Nothing bundled** — no credentials ship; bring your own keys.

## After you deploy

Give the agent an LLM — either set an API-key variable (`OPENAI_API_KEY`,
`OPENROUTER_API_KEY`, …) or authenticate a ChatGPT / Codex subscription over SSH:

```bash
railway ssh -s <service> -- hermes auth add openai-codex --type oauth --no-browser
```

Then **slim**: set a messaging token (`TELEGRAM_BOT_TOKEN`, …) to bring a channel
online — the gateway is already running. **Full**: open the generated domain, log in,
and configure providers/channels in the browser. For a persistent shell, use
`railway ssh -s <service> --session` (Railway provisions tmux on demand).

## Build it yourself (instead of the button)

Both variants live in this repo; each builds from its own subdirectory
(`variants/slim`, `variants/full`) with the service **Root Directory** set
accordingly and a volume attached. See the full phased recipe in
**[docs/hermes-railway-bringup.md](docs/hermes-railway-bringup.md)**.

## Layout

```
hermes-agent/
├── variants/
│   ├── slim/   Dockerfile + entrypoint + TEMPLATE.md   — python-slim, CLI+gateway, vol /data
│   └── full/   Dockerfile + entrypoint + TEMPLATE.md   — dashboard from source, vol /opt/data
├── assets/     icon.png · onboarding.png · dashboard.png   (marketplace artwork)
├── scripts/
│   ├── onboard-codex.sh    Codex device-flow auth (hermes auth add) + set model
│   ├── backup-pull.sh      export a profile + pull it down (+ git/R2 sink)
│   └── restore-profile.sh  fetch a profile tarball by URL + import it
└── docs/
    ├── hermes-railway-bringup.md   ← full step-by-step recipe
    ├── hermes-deep-dive.md         ← how Hermes works (sessions, personas, safety)
    └── upstream-changelog.md       ← which upstream release we pin + what it changed
```

The agent **profile** (prompt, skills, harness/loop config, memories, cron) is a
portable identity you can back up and restore on any device via
`hermes profile export/import` + the Railway volume + an off-box sink (git / R2 /
ssh-stream) — see `scripts/`.

## Credits

Hermes Agent is open source by **Nous Research**
([repo](https://github.com/nousresearch/hermes-agent), MIT). The "Nous Girl" icon is
from that repo. This is a **community** template, not an official Nous product.

> Tracking hermes-agent **v0.19.1** (upstream tag `v2026.7.30`). Containers are
> tmux-free; slim runs `hermes gateway run` as PID 1, full runs the dashboard +
> gateway. Check a running service with
> `railway ssh -s <service> -- printenv HERMES_PINNED_REF`.
