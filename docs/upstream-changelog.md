# Upstream changelog — what we pin, and what changed

**Currently pinned: [`v2026.8.3`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.3) — Hermes Agent `v0.20.0` (August 3, 2026).**

Both variants build from an upstream **release tag**, never `main`, so a template
deploy today and a template deploy next month produce the same agent. Bumping that
tag is a **manual step** — upstream ships fast (weekly-ish tags, thousands of commits
per window) and we only move after reading what landed.

This file is the record of that. It digests every upstream release we've passed
through, **so you never have to open the GitHub releases page to know what our
template picked up.** Upstream tags are **CalVer** (`v2026.7.30`); the package
version (`v0.19.1`) is a different number that appears in the release *title*.

| | |
|---|---|
| Upstream repo | https://github.com/NousResearch/hermes-agent |
| Upstream releases | https://github.com/NousResearch/hermes-agent/releases |
| Pinned in | `variants/slim/Dockerfile`, `variants/full/Dockerfile` → `ARG HERMES_REF` |
| Surfaced at runtime | `HERMES_PINNED_REF` env var + OCI image labels (see §Verify) |

---

## Pin history

| Pinned tag | Package | Date | Status |
|---|---|---|---|
| `v2026.8.3` | v0.20.0 | 2026-08-03 | **current** |
| `v2026.7.30` | v0.19.1 | 2026-07-30 | previous |
| `v2026.6.19` | v0.17.0 | 2026-06-19 | older |

---

## What we picked up: `v2026.7.30` (v0.19.1) → `v2026.8.3` (v0.20.0)

### `v2026.8.3` — v0.20.0 · August 3, 2026 · *"The Herald Release"* ← **we are here**

A **curated** release, and the notes explicitly roll up the whole v0.19.1 window — so
nothing is deferred this time. ~3,650 commits · ~1,400 PRs · ~1,200 issues closed ·
650+ contributors since v0.19.0.

Upstream's headline is **voice** (streaming TTS with barge-in, on-device wake words)
and the **desktop app becoming a platform**. Neither reaches this template — see
"skipped" below. What we actually gain is quieter and mostly runtime quality.

#### Matters for this template

- **Compression overhaul — the biggest win for a 24/7 gateway.** Per-turn
  micro-compaction replaces one long stall, a guaranteed N-user-message tail
  (`compression.min_tail_user_messages`) keeps recent conversation alive, absolute
  token thresholds (`compression.threshold_tokens`) and per-model overrides, plus
  "ghost-skill defense" so a pruned skill can't silently haunt a session. Sessions on
  an always-on gateway never end, so this is the failure mode we actually hit.
- **Gateway hardening** — session activity heartbeats, a stall watchdog, and bounded
  compression waits. Targets exactly the "agent silently wedged overnight" class.
- **Faster, lighter start** — the ~14s GIL stall during backend init is mitigated,
  heavy SDKs are lazily imported (−8–10% import cost), one raw `config.yaml` parse per
  process, readonly config loader (28× cheaper reads), and turn flush batched into a
  single SQLite transaction.
- **Tool self-recovery wave** — terminal output spills to a file instead of vanishing,
  `patch` diagnoses whitespace/ambiguous matches, searches probe for near-misses,
  `write_file` verifies on disk. Fewer wasted turns, which is real money.
- **Outbound signed webhooks** — HMAC-signed lifecycle events pushed to any endpoint.
  The first integration path for a headless agent that isn't a chat platform.
- **A2A v1.0** ships as a bundled platform plugin, and **Buzz** (Block's Nostr
  messenger) as a bundled gateway platform. Both arrive as plugin manifests — 96 now,
  up from 95 — and our `assets` stage picks them up automatically because it is
  parameterized on `HERMES_REF`.
- **Messaging fixes** — Slack native Block Kit clarify buttons, Discord auto-thread
  session keying and reply references without `fetch_message`, WhatsApp configurable
  inbound read receipts.
- **Prompt caching** — tool schemas cached on native Anthropic without history loss;
  Bedrock Converse `cachePoint`.
- **Model catalogs** — Gemini 3.1 Pro / 3.6 Flash, `claude-opus-5` via OpenRouter and
  Nous Portal, `deepseek-v4-flash-0731`.

#### Default changes that affect an unattended container

- **Tool-calling iteration limit 90 → 500.** Long autonomous runs stop hitting an
  artificial wall — but an unattended agent can now spend a great deal more per turn.
  Existing volumes are unaffected: they carry `agent.max_turns` in `config.yaml`
  (ours is 150). Only fresh deploys get 500.
- **`read_file` default limit 500 → 2000 lines** — larger reads, more context spent.
- **Runaway-loop caps** added for `web_search` and `delegate_task`, and a
  **consecutive-denial circuit breaker** for approvals. Both are guardrails, and both
  are new behaviour on an agent nobody is watching.
- **docker/podman daemon-redirect commands now require approval.**
- Config migration is now a table-driven registry with an **auto-migration floor at
  v12**. Ours are v33, so they migrate normally.

#### Not relevant to this template (skipped)

- The entire **desktop app** wave — artifacts with live preview, plugin SDK, quick-entry
  hotkey, multiple windows, 60fps rendering. We ship no Electron.
- **Voice and wake words.** Streaming TTS, barge-in, on-device wake phrases, and voice
  notes on WhatsApp/Feishu/DingTalk/LINE/QQ/Weixin all need the `voice` extra
  (faster-whisper + numpy + onnxruntime). Slim deliberately excludes it — adding it
  would undo the RAM figure the template is sold on.
- **CLI power commands** (`!shell`, `/init`, `/diff`, `/context`, `/focus`) — reachable
  over `railway ssh`, but not what this template is for.
- ACP model selection, desktop SSH remote backend.

#### Packaging status — unchanged, still needs our workaround

The `setup.py` wheel guard is **byte-identical** at this tag: a wheel still ships
without `locales`, `skills`, `optional-mcps`, `web_dist`, `tui_dist` and **plugin
manifests**. So `HERMES_NIX_BUILD=1` plus the `assets` stage (added 2026-08-08 in
3c675d7, after that exact omission silently killed every messaging adapter in slim)
remain required. The build-time assertion that telegram must register runs against
this tag too.

---

## What we picked up: `v2026.6.19` (v0.17.0) → `v2026.7.30` (v0.19.1)

Four upstream releases in that gap. Aggregate: **~4,000 commits, ~2,000 merged PRs,
~4,200 issues closed** across v0.18.0 and v0.19.0 alone, plus two patch rollups.

Each section below is tagged with what it actually means for **this template** — a
headless Railway container running `hermes gateway run` (slim) or dashboard +
gateway (full). Upstream spends a lot of its release notes on the **Electron desktop
app**, which we do not ship; that's called out and skipped.

---

### `v2026.7.30` — v0.19.1 · July 30, 2026 · *patch rollup*

An **infrastructure tag, not a curated release.** Upstream cut it explicitly "for
downstream consumers (Docker images, hosted deployments, fresh installs)" — which is
exactly us.

- **~2,789 commits · ~4,748 files changed · ~442,000 insertions · ~392,300 deletions**
  since v0.19.0.
- Content: bug-fix and salvage waves across the **gateway**, **voice subsystem**,
  desktop app, and installer; plus platform work — **Buzz/Nostr channel**, **FLUX3
  video generation and delivery**, **Telegram media reliability**, and voice-mode
  regression fixes.
- **No curated notes exist for this window.** Upstream states the full write-up ships
  with **v0.20.0**, which will document everything from v0.19.0 onward. Nothing is
  skipped — it's deferred.

**Relevant to us:** the gateway and Telegram fix waves. The large deletion count is
mostly the desktop tree's TypeScript conversion churn, not runtime removal.
**Watch for:** when v0.20.0 lands, re-read this window's notes and backfill the
digest below.

---

### `v2026.7.20` — v0.19.0 · July 20, 2026 · *"The Quicksilver Release"*

The last **curated** release. ~2,245 commits · ~1,065 PRs · ~3,300 issues closed ·
450+ contributors since v0.18.0. Also rolls up the v0.18.1 and v0.18.2 patch tags.

#### Matters for this template

- **~80% first-token latency cut, every platform.** Cold submit→dispatch went
  ~4.3s → ~0.9s: Discord capability detection moved off the critical path (token-keyed
  24h disk cache + background refresh), the Ollama probe is skipped for known
  non-Ollama providers, and blocking agent-init work was removed. Applies to CLI,
  **gateway**, TUI, and cron alike — so the Railway container answers faster.
- **Durable delivery-obligation ledger.** If the gateway died between generating a
  response and confirming the platform delivered it, that answer was **silently lost**
  (and you'd paid for the turn). Final responses are now recorded in a durable ledger
  in `state.db` around the platform send and **redelivered on next boot** — for
  Telegram, Discord, Slack, and every other channel. **This is the single biggest win
  for a Railway deploy**, where container restarts (redeploys, OOM, restart policy)
  are routine.
- **Gateway scale/robustness.** Per-session turn lease + conversation-scope funnel;
  unified session reset boundaries (reset sessions stay reset); truthful runtime
  readiness checks; per-channel model and system-prompt overrides; per-session
  `/model` overrides that persist across restarts. Session auto-reset now defaults
  **off**. `/sessions search <query>` added.
- **One gateway, many profiles.** A single multiplexed gateway on one bot token can
  route specific guilds/channels/threads to different profiles, each with isolated
  config, skills, memory, and secrets (`GATEWAY_MULTIPLEX_PROFILES`). A hardening wave
  means one misconfigured profile can no longer take down the whole gateway.
- **Smart approvals are now the default.** An LLM reviewer independently assesses
  flagged commands instead of prompting you for each one; each verdict covers only
  that exact command. Plus user-defined **deny rules** (block even under yolo mode)
  and `/deny <reason>` so the agent course-corrects. Note the default change: an
  unattended Railway agent now self-approves more than it did on v0.17.0 — set deny
  rules if that's not what you want.
- **Secrets from a password manager.** Pluggable `SecretSource` interface with
  **Bitwarden** and **1Password** (`op://` refs) providers, multiple vaults at once,
  deterministic precedence, per-variable provenance. An alternative to our
  entrypoint's Railway-vars→`.env` mirroring if you'd rather not put keys in Railway.
- **New providers + frontier models.** **Fireworks AI** (with cost estimation, #2 in
  the provider picker) and **DeepInfra** as first-class providers; Upstage Solar via
  salvage. Catalogs gained **GPT-5.6** (Sol/Terra/Luna + Pro, wired end-to-end),
  **grok-4.5** (GA), **moonshotai/kimi-k3** (kimi-k2.x retired), **claude-fable-5 /
  claude-sonnet-5**, GA **tencent/hy3**, and a Bedrock catalog wave with live
  context-window probing. New `enabled: false` per-provider flag and
  `excluded_providers` config to scrub unwanted providers from `/model`.
- **Reasoning effort as a dial.** New `max` and `ultra` tiers, per-model
  `reasoning_effort` overrides via one resolution chokepoint, per-task auxiliary
  effort, per-slot MoA preset effort, session-scoped `/reasoning`.
- **Messaging platform work.** Inline one-tap choice pickers for `/reasoning` and
  `/fast` on **Telegram, Discord, Matrix**. Discord: recovers messages missed during
  reconnect, auto-created threads renamed to generated session titles, configurable
  interactive-view timeout, optional admin-only gate on approval buttons. Slack: live
  per-tool status line. Telegram: per-topic free-response allowlist. WhatsApp: native
  Baileys polls, locations, rich inbound metadata, dashboard pairing flow.
- **Web dashboard (full variant only).** Memory-provider switching, safe session
  import, WhatsApp pairing, Discord-specific toolsets editable from the web UI,
  terminal keep-alive + reattach for dashboard chat sessions, heavy turns isolated in
  a compute host, paste/drop images into chat, profile + gateway topology on
  `/api/status`, mobile/hosted OpenAI OAuth login. **`hermes serve` is now a true
  headless backend** (no web UI build/mount).
- **Sessions are exportable data.** `hermes sessions export` writes Markdown, Quarto,
  HTML, prompt-only, and Hugging Face-ready trace formats, with age/workspace/platform
  filters, opt-in `--redact` secret scrubbing, and compacted-session lineage stitched
  into one export. Relevant to `scripts/backup-pull.sh`.
- **Storage layout moved.** Gateway session metadata and the routing index consolidated
  into **`state.db`**; `sessions.json` is now an optional legacy mirror. Exact API bytes
  persist in an `api_content` sidecar. Both live on our Railway volume — expect
  `state.db` to grow and `sessions.json` to go quiet.
- **Security round.** Vertex credentials scoped away from subprocess env; media/vision/
  image-gen local-file reads routed through one shared credential-read guard; explicit
  `client_max_size` body caps on three uncapped aiohttp servers (webhook surfaces);
  timestamp-bound V2 webhook signatures; bot-token redaction in Telegram transport
  errors; Fireworks token prefixes added to the redactor; dashboard managed-files
  credential guard widened past `.env`; OAuth token TOCTOU closed with atomic `0o600`
  writes; Anthropic request-local clients so the interrupt watchdog can't corrupt
  SQLite.
- **CLI.** `/subscription` + `/topup` manage a Nous plan from the terminal.
  `/model --once` for a one-turn override. Stacked slash-skill invocations
  (`/skill-a /skill-b do XYZ`). `--safe-mode` troubleshooting flag. TLS failures fail
  fast with fix hints. **pip/Homebrew installs are warned as unsupported upstream** —
  we install via `uv pip … @ git+…@<tag>`, which stays fine, but it's why we pin.
- **MCP.** `mcp__server__tool` naming convention; server log notifications surfaced in
  `agent.log`; hosted OAuth completed across dashboard; configurable
  `redirect_uri`/`redirect_host` for proxied/WAF setups (relevant behind Railway's
  edge); OAuth callback port races closed.
- **Deprecated:** `max_async_children` (delegation concurrency caps unified).
  `hermes doctor` now reports deprecated config keys and warns on unknown root keys.

#### Not relevant to us (skipped)

The **desktop app speed wave** (20+ perf PRs — 14× faster streaming markdown,
virtualized diffs, session-switch layout-thrash fixes), the contribution-driven
shell/layout-tree model, Capabilities page, Hermes Cloud connection mode, worktree
dialogs, session color system, and the full TypeScript conversion of the desktop
tree. We ship no Electron app.

#### Reverted upstream in this window (does **not** ship)

iron-proxy credential-injection egress firewall; the dynamic-workflow orchestration
skill; the memory provider-actions extension point. (The plugin `pre_tool_call`
approve escalation was reverted mid-window but **re-landed** and does ship.)

---

### `v2026.7.7.2` — v0.18.2 · July 7, 2026 · *same-day patch*

One fix, and it's a **build** fix that matters to us:

- **fix(whatsapp): unpin Baileys from a git commit, use published `7.0.0-rc13`** —
  the WhatsApp bridge dependency now installs from the published npm release instead
  of a pinned git commit, "making installs and **Docker image builds** reliable."
  Directly relevant to the **full** variant, which runs `npm install` at the repo root
  during its Node build stage.

---

### `v2026.7.7` — v0.18.1 · July 7, 2026 · *patch rollup*

Infrastructure tag, not curated. ~667 commits across ~990 files (+89.5k/−10.4k) in the
six days after v0.18.0: installer/updater self-healing on Windows, dashboard and
gateway fixes, WhatsApp dashboard pairing, MCP and provider fixes, broad stability
work. Fully documented inside the v0.19.0 notes above.

---

### `v2026.7.1` — v0.18.0 · July 1, 2026 · *"The Judgment Release"*

~1,720 commits · 998 PRs · 949 issues closed · 370+ contributors since v0.17.0 — the
release that immediately followed our old pin.

- **The P0/P1 clean sweep.** Every P0 and P1 issue and PR in the entire repo closed —
  496 issues + 196 PRs, ~692 highest-priority items, open P0/P1 hitting **0**.
  This is the main reason our old `v2026.6.19` pin was worth leaving.
- **Gateway becomes deployable at scale.** **Scale-to-zero when idle** and clean
  quiesce before a restart, migration, or auto-update — without dropping in-flight
  conversations. Disruptive lifecycle actions coordinate an external drain. Directly
  improves how our container behaves across Railway redeploys.
- **Mixture-of-Agents is a first-class model.** Every named MoA preset appears as a
  selectable model under a `moa` provider in every picker (CLI, TUI, gateway). Each
  reference model's reasoning renders as its own labelled block, and the aggregator's
  answer streams live. `/moa` is now one-shot sugar.
- **The agent verifies its own work.** Hermes records verification evidence for coding
  work and decides "done" by running your project's checks, not by asserting success.
  `/goal` gained **completion contracts**; there's a `pre_verify` hook.
- **`/learn <anything>`** distills a reusable skill out of a directory, a URL, or the
  workflow you just walked through. **`/journey`** is a playable timeline of every
  memory and skill the agent has accumulated, editable/prunable in place.
- **Background fan-out delegation.** `delegate_task` fans out multiple subagents that
  run in the background without blocking the chat; results return as one consolidated
  turn.
- **Cheaper self-improvement.** The post-turn fork that decides whether to save a
  memory or skill now routes to an **auxiliary model**, digests context instead of
  replaying the whole conversation, and adapts its cadence — the self-improvement loop
  costs a fraction of what it did. Real money on an always-on Railway agent.
- **Google Vertex AI** as a first-class provider for Gemini, with short-lived OAuth2
  tokens minted and auto-refreshed from a service account or ADC (a plain
  custom-provider setup always died mid-session because Vertex has no static key).
- **`/prompt`** opens `$EDITOR` to compose a long multi-line prompt.
- **Security round.** MCP-config persistence surface locked down; cron `base_url`
  overrides that could exfiltrate provider credentials blocked; non-reusable sentinel
  for prefix secrets in file reads; Slack app-level (`xapp-`) token redaction; browser
  cloud-metadata floor enforced on every backend; `aiohttp` CVE floor across the lazy
  messaging paths.

---

## Build-level consequences of the v0.19.x bump (what we had to change)

Three things broke or degraded when moving off `v2026.6.19`. All are fixed in our
Dockerfiles; each is a standing constraint to re-check on the **next** bump.

### 1. Upstream now refuses to build a wheel (slim)

`setup.py` at `v2026.7.30` gained `_GuardedSdist` / `_GuardedBdistWheel`, which raise:

> `RuntimeError: Building wheels or sdists for hermes-agent is not supported.`
> `Hermes is distributed via the shell installer, Docker image, or Nix.`

This kills a plain `uv pip install "hermes-agent[...] @ git+...@<tag>"`. **New in
`v2026.7.30` only** — `v2026.6.19` and `v2026.7.20` build fine.

We set **`HERMES_NIX_BUILD=1`** on the install step. That's upstream's own escape
hatch for their Nix derivation, and skipping the policy guard is the *only* thing it
does — the resulting build is identical to what `v2026.7.20` produced.

Rejected alternative: an editable install from a shallow clone (what upstream's error
message recommends). Measured **131.3 MiB RSS vs 88.5 MiB** for the flag — Railway
bills RAM, so that's ~48% more cost forever, and it breaks the "~112 MB" claim the
slim template is positioned on. It also trips Hermes' "refusing to run the gateway as
root inside the official Docker image" guard (a clone at `/opt/hermes` looks like the
official image), so it would additionally need `HERMES_ALLOW_ROOT_GATEWAY=1`.

**On the next bump:** if the flag stops working the *build* fails loudly, so no broken
image can reach deployers. Re-evaluate the editable path then.

### 2. The web dashboard gained a workspace dependency (full)

`web/package.json` now has `"@hermes/shared": "file:../apps/shared"`, so our
`rm -rf apps` (which existed to drop the Electron desktop workspace) deleted a build
input — `tsc -b` failed with ~20 `Cannot find module '@hermes/shared'` errors.

Fixed by narrowing to `rm -rf apps/desktop apps/bootstrap-installer`. **This
dependency predates `v2026.7.20`**, so the full variant was broken at *both* candidate
tags, not just the newest.

### 3. SQLite on the Debian base is too old — WAL silently disabled

Both variants logged, once per database:

> `linked SQLite 3.40.1 is vulnerable to the WAL-reset corruption bug — using`
> `journal_mode=DELETE instead of enabling WAL.`

Hermes requires **≥ 3.51.3** (or backports 3.50.7 / 3.44.6). Bookworm ships 3.40.1
and **trixie only 3.46.1 — a base-image swap does NOT fix this** (upstream's own
Dockerfile says so explicitly and compiles SQLite instead).

This matters far more at v0.19.0 than it did at v0.17.0, because that release moved
gateway session metadata, the routing index, and the new durable delivery ledger
**into `state.db`**. Falling back to `journal_mode=DELETE` costs write concurrency on
the database the gateway now leans on hardest.

We mirror upstream: a `sqlite_build` stage compiles **SQLite 3.53.4** with their exact
CFLAGS, and the runtime stage drops it over `libsqlite3.so.0` via `/usr/local/lib` +
`ld.so.conf.d/000-sqlite-fixed.conf` + `ldconfig`, with a build-time self-test that
fails the build if the linked version is still `< 3.51.3`. Built on bookworm so the
`.so` matches the runtime's glibc.

### 4. `tirith` self-downloads at first boot

The exec-safety scanner is **not** shipped in upstream's image either, so at runtime
it fetched `latest` from a **third-party repo** (`sheeki03/tirith`) into
`$HERMES_HOME/bin` — i.e. **the billed Railway volume** — with SHA-256 verification
only (`cosign not on PATH — installing tirith with SHA-256 verification only`).

We pin **`v0.3.3`** in a build stage, verify it against the release `checksums.txt`,
and install it to `/usr/local/bin/tirith`. `shutil.which("tirith")` finds it, so the
auto-installer never fires: no first-boot egress, no volume write, no unpinned
`latest`. Multi-arch via `TARGETARCH` (Railway builds amd64).

Runtime override if you'd rather not run it at all: **`TIRITH_ENABLED=false`**
(Hermes falls back to pattern-matching guards). `TIRITH_BIN` sets an explicit path.

---

## How to bump the pin

**Read the `railway-templates` skill's `references/template-updates.md` before
touching the Railway marketplace template** — there are referral-credit and
slug-stability rules that must not be broken (§5 there is this repo's worked
example). Metrics after a bump: `references/template-metrics.md` in the same skill.

Short version:

1. Read the new release notes; add a digest section to this file (newest first) and
   move the old pin into **Pin history**.
2. `ARG HERMES_REF=<new-tag>` in **both** `variants/slim/Dockerfile` and
   `variants/full/Dockerfile`, and bump the `…image.version` / `…hermes.release`
   labels alongside it.
3. Update the "tracks upstream" line in `README.md` and in both `TEMPLATE.md` files.
4. Commit + push. The marketplace templates build from this GitHub repo, so **new
   deploys pick the change up automatically** — no template operation required for a
   Dockerfile change.
5. Verify a real cold start (build both variants, check RSS and that the gateway
   answers) **before** touching the published template metadata.

## Verified locally for this bump (2026-08-02, arm64)

Both variants built cold (`--no-cache`) and were exercised by actually running the
`hermes` CLI inside the container — not just `--version`, which doesn't prove the
import graph, config system or session store work.

| | slim | full |
|---|---|---|
| CLI banner | `Hermes Agent v0.19.1 (2026.7.30)` · 17 tools | same · 17 tools · 66 skills |
| SQLite linked | **3.53.4** (was 3.40.1) | **3.53.4** |
| WAL-reset warnings at boot | **0** (was 4+) | **0** |
| tirith | preinstalled `0.3.3` on PATH, **0** runtime downloads | same |
| steady RSS | **86.7 MiB** (claim: ~112 MB) | **228.5 MiB** (claim: ~300 MB) |
| restarts in 75s | 0 | 0 |
| image | 734 MB | 1.22 GB |
| cold build | **97s** (baseline 95s → **+2s**) | **98s** |

**Keeping the build fast is structural, not incidental.** The SQLite override only
matters at *runtime*, never during `uv pip install` — so slim compiles it in a
separate `deps` stage and puts the `COPY --from=deps` **after** the slow Hermes
install. BuildKit then runs the ~58s compile concurrently with the ~80s install and
it costs ~2s of wall clock. Folding the same work into the install's own `RUN`
instead measured **137s** (+42s). The full variant keeps its SQLite inline because
it already overlaps the Node/vite dashboard stage and gets the same benefit for free.

If you ever restructure these files, preserve that ordering — moving the `COPY`
above the install silently costs ~40s on every template deploy.

> **RSS figures above are arm64.** Railway builds amd64, so treat them as indicative
> and re-measure on the deployed service before changing any marketing claim.

Reproduce:

```bash
docker build --no-cache -t hermes-slim:test variants/slim
printf '/exit\n' | docker run --rm -i -e OPENAI_API_KEY=sk-test \
  --entrypoint hermes hermes-slim:test        # expect the v0.19.1 banner
docker run --rm --entrypoint /opt/venv/bin/python hermes-slim:test \
  -c "import sqlite3;print(sqlite3.sqlite_version)"   # expect >= 3.51.3
docker run --rm --entrypoint sh hermes-slim:test -c 'tirith --version'
```

## Verify what a running container is pinned to

```bash
# from the outside
docker inspect --format '{{index .Config.Labels "com.nousresearch.hermes.release"}}' <image>

# from inside a deployed Railway service
railway ssh -s <service> -- printenv HERMES_PINNED_REF     # e.g. v2026.7.30
railway ssh -s <service> -- hermes --version               # e.g. 0.19.1
```
